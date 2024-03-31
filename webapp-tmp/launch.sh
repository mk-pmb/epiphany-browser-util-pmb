#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function epiphany_webapp_tmp () {
  local SELFPATH="$(readlink -m -- "$BASH_SOURCE"/..)"

  local -A CFG=(
    # [cfgtpl]="$HOME"/.gnome2/epiphany
    [debug]="$EPHY_WEBAPP_DEBUG"
    [ephy_prog]='epiphany-browser'
    )

  local DBGLV="${DEBUGLEVEL:-0}"
  [ "$DBGLV" -lt 1 ] || CFG[debug]+=",$DBGLV"
  [ "$DBGLV" -lt 2 ] || CFG[debug]+=',verbose'
  [ "$DBGLV" -lt 12 ] || CFG[debug]+=',trace'

  if [ "$1" == --func-early ]; then shift; "$@"; return $?; fi

  local EPHY_VER_SERIAL=; detect_ephy_version_serial || return $?
  CFG[wa_prefix]="$(guess_ephy_web_app_prefix)"
  case "$1" in
    --func ) shift; "$@"; return $?;;
    --ephy-serial-ver ) echo "$EPHY_VER_SERIAL"; return $?;;
  esac

  cd / || return 4$(echo E: 'Failed to chdir to root directory!?' >&2)
  local OPT=
  while [ "$#" -gt 0 ]; do
    OPT="$1"; shift
    case "$OPT" in
      '' ) ;;
      --debug ) CFG[debug]='verbose';;
      --cfgtpl=* | \
      --debug=* | \
      --icon=* | \
      --title=* | \
      --tmpdir=* | \
      --url=* | \
      --winsize=* | \
      --wmclass-part=* | \
      --cfg:*=* ) cli_cfg_opt "$OPT";;
      --keep-profile | \
      --cfg:* ) cli_cfg_opt "$OPT"=+;;
      -* )
        local -fp "${FUNCNAME[0]}" | guess_bash_script_config_opts-pmb
        [ "$OPT" == --help ] && return 0
        echo "E: $0, CLI: unsupported option: $OPT" >&2; return 1;;
      *://* ) CFG[url]="$OPT";;
      * ) return 1$(echo "E: $0, CLI: unexpected positional argument." >&2);;
    esac
  done

  [ -n "${CFG[url]}" ] || return 1$(echo 'E: missing --url=' >&2)
  [ -n "${CFG[tmpdir]}" ] || CFG[tmpdir]=tmp-app-
  case "${CFG[tmpdir]}" in
    '~/'* ) CFG[tmpdir]="$HOME/${CFG[tmpdir]:2}";;
    /* ) ;;
    * ) CFG[tmpdir]="$HOME/.cache/${CFG[ephy_prog]}/${CFG[tmpdir]}";;
  esac
  if [ -z "${CFG[icon]}" ]; then
    CFG[icon]=/usr/share/icons/gnome/
    CFG[icon]+='48x48/categories/applications-internet.png'
  fi

  local WMCTRL_LURK=()
  [ -n "${CFG[title]}" ] && WMCTRL_LURK+=( -, -T "${CFG[title]}" )
  local WIN_SZ="${CFG[winsize]}"
  case "$WIN_SZ" in
    [0-9]*x[0-9]* )
      WIN_SZ="${WIN_SZ/x/,}"
      WMCTRL_LURK+=( -, -b remove,maximized_vert,maximized_horz )
      WMCTRL_LURK+=( -, -e 0,-1,-1,"$WIN_SZ" )
      ;;
  esac

  local WM_CLS_PART="${CFG[wmclass_part]}"
  if [ -z "$WM_CLS_PART" ]; then
    WM_CLS_PART="$(<<<"$*" md5sum)"
    WM_CLS_PART="${WM_CLS_PART%% *}"
  fi
  if [ -n "${CFG[wa_prefix]}" ]; then
    if [[ "$WM_CLS_PART" == *"${CFG[wa_prefix]}"* ]]; then
      echo "E: wmclass_part cannot contain '${CFG[wa_prefix]}', because" \
        "epiphany uses that to mark the start of its wmclass." >&2
      return 1
    fi
  fi

  local PROFILE=; ensure_profile_dir || return $?

  for OPT in url icon; do
    [ "${CFG[$OPT]:0:2}" == '~/' ] && CFG["$OPT"]="$HOME/${CFG[$OPT]:2}"
  done
  for OPT in url; do
    [ "${CFG[$OPT]:0:1}" == '/' ] && CFG["$OPT"]="file://${CFG[$OPT]}"
  done

  local TRACE=()
  [[ ",${CFG[debug]}," == *,verbose,* ]] || TRACE+=( run_muted )
  if [[ ",${CFG[debug]}," == *,trace,* ]]; then
    TRACE+=( strace -y -f -o "$PROFILE.strace.log" )
    echo "D: trace: ${TRACE[*]}" >&2
  fi

  local APP_NAME="${CFG[wa_prefix]}$WM_CLS_PART"
  local APP_SHARE_DIR="$HOME/.local/share/$APP_NAME"
  mkdir --parents -- "$APP_SHARE_DIR"

  prepare_png_image "${CFG[icon]}" "$APP_SHARE_DIR"/app-icon.png || return $?
  [ -f "$PROFILE"/app-icon.png ] || ln --symbolic \
    --target-directory "$PROFILE" -- "$APP_SHARE_DIR"/app-icon.png || return $?
  WMCTRL_LURK+=( -, icon "$APP_SHARE_DIR"/app-icon.png
    ) # ^-- Because on Ubuntu focal and later, epiphany ignores the app icon.

  [ -d "$PROFILE/$APP_NAME" ] || ln --symbolic \
    --no-target-directory -- . "$PROFILE/$APP_NAME" || return $?
  ensure_required_desktop_file || return $?

  local WM_NAME_CLS=( "${CFG[ephy_prog]}" "$WM_CLS_PART" ) # v3.10.3
  [ "$EPHY_VER_SERIAL" -lt 3'0036'0000 ] || WM_NAME_CLS=( "$APP_NAME"{,} )

  local EPI_CMD=(
    "${CFG[ephy_prog]}"
    --application-mode
    --profile="$PROFILE/$APP_NAME"
    "${CFG[url]}"
    )
  if [[ ",${CFG[debug]}," == *,verbose,* ]]; then
    { echo -n "D: profile: $PROFILE = "; ls -alF -- "$PROFILE"
      echo -n 'D: run: '; printf -- ' ‹%s›' "${EPI_CMD[@]}"; echo
    } >&2
  fi
  </dev/null "${TRACE[@]}" "${EPI_CMD[@]}" &
  local EPI_PID="$!"

  if [ -n "${WMCTRL_LURK[0]}" ]; then
    wmctrl-pid-each --lurk 30 1s "$EPI_PID" "${WMCTRL_LURK[@]}" &
    disown $!
  fi

  check_broken_config_dir || return $?

  if [[ ",${CFG[debug]}," == *,verbose,* ]]; then
    sleep 1
    echo -n "D: ps ${CFG[ephy_prog]}:"
    ps --no-header -o args -C "${CFG[ephy_prog]}" || echo "W: no such process"
    echo -n "D: epiphany pid: $EPI_PID = "
    ps --no-header -o args "$EPI_PID" || echo "W: no such process"
    echo -n "D: wmctrl: "
    wmctrl -xl | grep -Fe " ${WM_NAME_CLS[0]}.${WM_NAME_CLS[1]} " \
      --color=always || echo "W: no such window"
  fi
  wait

  maybe_rm_profile || return $?
}


function cli_cfg_opt () {
  local KEY="${1%%=*}"
  local VAL="${1#*=}"
  [ "$VAL" == "$KEY" ] && VAL=
  KEY="${KEY#--cfg:}"
  KEY="${KEY#--}"
  KEY="${KEY//-/_}"
  CFG["$KEY"]="$VAL"
}


function run_muted () { exec &>/dev/null; exec "$@"; }


function detect_ephy_version_serial () {
  EPHY_VER_SERIAL="$(epiphany-browser --version | sed -nrf <(echo '
    s~\.~.000000~g
    s~^Web ([0-9]+)\.0*([0-9]{4})\.0*([0-9]{4})$~\1\2\3~p
    '))"
  [ -n "$EPHY_VER_SERIAL" ] || return 4$(
    echo "E: Failed to detect epiphany version" >&2)
}


function prepare_png_image () {
  local ORIG="$1" DEST="$2"
  rm -- "$DEST" 2>/dev/null
  local CONV_CMD=()
  case "$ORIG" in
    *.png )
      ln --symbolic --no-target-directory -- "$ORIG" "$DEST"
      return $?;;
    *.svg )
      # In Ubuntu trusty, epiphany was able to deal with SVG directly,
      # but in xenial, the default icon will be used instead of the SVG.
      # In Xenial we can't use "convert" (from "ImageMagick 6.8.9-9 Q16
      # i686 2019-11-12") either, because it would fail (rv=134, "Aborted")
      # to convert lots of the /usr/share/icons/Humanity/*/48/*.svg icons.
      CONV_CMD=( rsvg-convert --output "$DEST" -- "$ORIG" );;
    * ) CONV_CMD=( convert -background none -- "$ORIG" "$DEST" );;
  esac
  "${CONV_CMD[@]}" || return $?$(
    echo "E: failed (rv=$?) to '${CONV_CMD[0]}' image '$ORIG' to '$DEST'!" >&2)
}


function guess_ephy_web_app_prefix () {
  <<'  __DOC__'

  Defined in lib/ephy-web-app-utils.h, found online as
  http://git.gnome.org/browse/epiphany/tree/lib/ephy-web-app-utils.h
  Way back in 2013, it was just "app-".

  Unfortunately, the devs have a tendency to changed it a lot:
  On 2022-04-14, the repo says ".WebApp_",
  but the error message says "epiphany-".
    => auto-detect it!

  `strings /usr/lib/x86_64-linux-gnu/epiphany-browser/libephymisc.so`
  only finds the error message with a placeholder:
  "Profile directory %s does not begin with required web app prefix %s"

  I tried objdump and readelf on /usr/bin/epiphany and
  /usr/lib/x86_64-linux-gnu/epiphany-browser/*.so
  but it found neither "application" nor "epiphany-" in an
  auspicious context.

  Seems like we have to provoke the error message to find out.

  __DOC__

  [ "$EPHY_VER_SERIAL" -le 3'0010'9999 ] && return 0

  # Even with wrong prefix, it must exist: "--profile must be an
  # existing directory when --application-mode is requested"

  local PROG="${CFG[ephy_prog]}"
  local DUMMY="$HOME/.cache/$PROG/work-arounds/provoke_wrong_prefix_error"
  mkdir --parents -- "$DUMMY" || return $?
  local SED='
    s~\a~~g
    s~: Profile directory (\S+) does not begin with required web app prefix |$\
      ~\n\1\n~p
    '
  local EPI_CMD=(
    "$PROG"
    --application-mode
    --profile="$DUMMY"
    -- about:blank
    )
  [[ ",${CFG[debug]}," == *,verbose,* ]] \
    && echo "D: $FUNCNAME: ${EPI_CMD[*]}" >&2
  SED="$("${EPI_CMD[@]}" |& sed -nrf <(echo "$SED"))"
  SED="${SED#*$'\n'}"
  local RE_DUMMY="${SED%%$'\n'*}"
  if [ "$RE_DUMMY" != "$DUMMY" ]; then
    echo "W: $FUNCNAME:" \
      "Profile path reported in error message differs from CLI arg." >&2
    echo "W: Requested profile path: $DUMMY" >&2
    echo "W: Reported  profile path: $RE_DUMMY" >&2
  fi
  SED="${SED#*$'\n'}"
  [ -n "$SED" ] || return 4$(echo "E: $FUNCNAME: Unable to guess prefix" >&2)
  echo "$SED"
}


function ensure_required_desktop_file () {
  # 2022-04-14, Ubuntu focal: "Required desktop file not present at
  # /home/…user…/.cache/epiphany-browser/…tmp…/…app…/…app….desktop
  local DF="$PROFILE/$APP_NAME.desktop"
  printf -- '%s\n' \
    '[Desktop Entry]' \
    'Type=Application' \
    >"$DF" || return $?
  # ^-- This .desktp file is only required for make ephy v3.36.4 start at all.
  #     Ephy seems to not care about any more details than Type.

  DF="$APP_SHARE_DIR/$APP_NAME.desktop"
  # ^-- When opening the Preferences from the main menu, ephy v3.36.4
  #     complains about not being able to read this file.
  #     If this file contains a "Title=", the Preferences dialog crashes.

  # However, Name= and Icon= seem to not have any effect. The window title
  # atop is still "Unnamed" and the icon still default.
  # :TODO: I have not yet figured out whether and where epiphany would save
  # the name and icon settings if they are changed in Preferences.
  printf -- '%s\n' \
    '[Desktop Entry]' \
    'Type=Application' \
    "Name=${CFG[title]}" \
    "Icon=${CFG[icon]}" \
    >"$DF" || return $?
  chmod a+x -- "$DF" || return $?
}


function ensure_profile_dir () {
  PROFILE="${CFG[profile_dir]}"
  if [ -n "$PROFILE" ]; then
    CFG[keep_profile]=+
    [ -d "$PROFILE" ] && return 0
    mkdir --parents --mode='a=,u+rwX' -- "$$PROFILE"
    [ -d "$PROFILE" ] && return 0
    echo "E: profile dir not found: $PROFILE" >&2
    return 3
  fi

  [ -n "$WM_CLS_PART" ] || return 4$(echo 'E: Empty WM_CLS_PART!' >&2)
  mkdir --parents -- "${CFG[tmpdir]}" || return $?
  PROFILE="$WM_CLS_PART"
  [ -n "$PROFILE" ] && PROFILE+='.'
  PROFILE="$(mktemp --tmpdir="${CFG[tmpdir]}" --directory "$PROFILE"XXXXXXXX)"
  [ -d "$PROFILE" ] || return 3$(
    echo E: "cannot create profile dir: $PROFILE" >&2)

  local SRC= BFN=
  for SRC in "$SELFPATH"/profile_blobs/*.gz; do
    BFN="$(basename -- "$SRC" .gz)"
    gunzip <"$SRC" >"$PROFILE/$BFN" || return 3$(
      echo E: "Cannot unpack profile blob '$BFN'" >&2)
  done

  CFG['profile_was_tmp_created']=+
  install_config_template "${CFG[cfgtpl]}" || return $?
}


function install_config_template () {
  local CTPL="${CFG[cfgtpl]}"
  [ -n "$CTPL" ] || return 0
  [ -d "$CTPL" ] || return 4$(
    echo E: "Config template seems to not be a directory: $CTPL" >&2)
  cp --recursive --no-target-directory -- "$CTPL"/ "$PROFILE" || return 4$(
    echo E: "Failed to copy config template $CTPL -> $PROFILE" >&2)
}


function maybe_rm_profile () {
  [ "${CFG['profile_was_tmp_created']}" == + ] || return 0
  [[ ",${CFG[debug]}," == *,no-rm-tmp,* ]] && return 0
  [ -n "${CFG[keep_profile]}" ] && return 0
  [ -d "$PROFILE" ] || return 0
  rm --one-file-system --recursive \
    -- "${PROFILE:-/::E_NO_PROFILE::/}" || return $?
}


function check_broken_config_dir () {
  local HGE="$HOME"/.gnome2/epiphany
  local CHECKS=(
    "-d|$HGE/adblock/|Might cause slooooow startup."
    )
  local ITEM= OPER= HINT= WARN=
  for ITEM in "${CHECKS[@]}"; do
    OPER="${ITEM%%|*}"
    ITEM="${ITEM#*|}"
    HINT="${ITEM#*|}"
    ITEM="${ITEM%%|*}"
    test "$OPER" "$ITEM" && continue
    WARN+="Failed check $OPER for $ITEM"
    [ -z "$HINT" ] || WARN+=" ($HINT)"
    WARN+=$'\n'
  done
  [ -n "$WARN" ] || return 0

  ITEM="$APP_NAME startup checks"
  echo W: "$ITEM: $WARN" >&2
  gxmessage -title "$ITEM" \
    -buttons GTK_STOCK_CLOSE:0 \
    -default GTK_STOCK_CLOSE \
    -file - <<<"$WARN" &
  disown $!
}











epiphany_webapp_tmp "$@"; exit $?
