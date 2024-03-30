
How to re-create the binary files
=================================

1.  Close all open epiphany instances.
1.  Ensure that `$HOME/.local/share` has no subdirectories whose name
    starts with `epiphany-webapp-blobs-`.
    (If it has and you don't need them, delete them.
    If you need them, make and use a new user account for this.)
1.  Start `epiphany-browser` in full browser mode.
1.  Navigate to this URL (copy into the location bar):
    `data:text/html,<title>webapp-blobs</title>Hello.`
1.  You should now see a blank page with the text "Hello." on it.
1.  From the hamburger menu (&#x2630;/&#x2261;),
    select "Install Site as Web Application…".
1.  The next step may trigger a notification that may have a time limit.
    Nothing really important – being quick just saves a little effort.
1.  In the lower part, there should be a text box with the text
    "webapp-blobs". Click there and press the return key.
1.  Near your system tray, a notification may pop up to inform you that
    a web application has been created. It may have a launch button.
    Optionally try to click that and wait a moment for the app to open.
1.  If the app did *not* open, launch it from your applications menu.
    Its menu entry should be labeled "webapp-blobs" and it's probably in
    the "Other" or "Miscellaneous" category.
1.  Close the initial epiphany that you started in full browser mode.
1.  In the "webapp-blobs" epiphany, from the hamburger menu (&#x2630;/&#x2261;),
    select "Preferences".







1.  Open a shell in the directory of this readme file.
    (If you're reading this online, you may first need to clone the repo
    to a local directory.)



