#!/bin/sh

#PJ 
# hopefully, the tablet buttons will get distinct keycodes again...

# kvkbd and the others except cellwriter get the codes from
# the current xmodmap, thus incl. the messed-up number row
# which is sacrifized for the joystick key.

# in a addition, pen does NOT equal mouse, things like copy/paste
# get difficult if you lack at least one button and always move
# the pointer with button presses. Also, modifiers for e.g. 
# alt-left-clicking a window fail unless I abuse
# the lone button as a modifier.

# tip is left, tip+button is right, double click as usual
xsetwacom set eraser Button1 "button 2" # middle mouse button

# values for a rotation-surviving skew of the pointer from
# wacomcpl callibration
xsetwacom set stylus TopX    1
xsetwacom set stylus TopY -106

# for now there seems to be no need to disable things in HAL


orientation="$1"
if [ "$orientation" = "" ]; then
   orientation=left # new orientation: tablet mode or return to normal?
   xrandr | grep default | grep 'left.(' >/dev/null && orientation=normal
fi
[ "$orientation" = "tablet" ] && orientation=left

if [ "$orientation" = 'normal' ]; then
	xrandr -o normal
	xsetwacom set stylus rotate 0
	xsetwacom set eraser rotate 0
#       xmodmap /dev/stdin <<EOF
#           keycode  10 = Up       exclam 1 exclam onesuperior exclamdown      
#           keycode  11 = Down     at 2 quotedbl twosuperior oneeighth
#           keycode  12 = Left     numbersign 3 section threesuperior sterling
#           keycode  13 = Right    dollar 4 dollar onequarter currency
#           keycode  14 = Return   percent 5 percent onehalf threeeighths
#           keycode  15 = 6 asciicircum 6 ampersand notsign fiveeighths
#EOF
        xmodmap /dev/stdin <<EOF
           keycode  10 = 1 exclam 1 exclam onesuperior exclamdown      
           keycode  11 = 2 at 2 quotedbl twosuperior oneeighth
           keycode  12 = 3 numbersign 3 section threesuperior sterling
           keycode  13 = 4 dollar 4 dollar onequarter currency
           keycode  14 = 5 percent 5 percent onehalf threeeighths
           keycode  15 = 6 asciicircum 6 ampersand notsign fiveeighths
EOF
elif [ "$orientation" = 'left' ]; then
	xrandr -o left
        ps -ef | grep -e vkbd -e cellwriter | grep -v grep >/dev/null || {
           # cellwriter does both pen and onscreen keyboard entry
           # and is also not fazed by the borked xmodmap
           cellwriter >/dev/null 2>&1 & 
        }
        ps -ef | grep -e easystroke | grep -v grep >/dev/null || {
           # some gestures for terminal window, firefox and e.g. 
           # cellwriter or onscreen keyboards, works
           easystroke >/dev/null 2>&1 &
        }
        # possible: a small button based menu to open stuff or rotate.
        #           but the rotation script might just as easily be
        #           placed in easystroke
	# no autostart: xournal (combining text and pdf editing w pen)
	
        xsetwacom set stylus rotate 2
	xsetwacom set eraser rotate 2
        # extra mappings for the joystick key, but
        # the keycode is idx to the number keys,
        # excepting the super_r which i cannot use
        # for remapping here...
        #
        # 6 - maybe use as hotkey... or modifier instead?
        xmodmap /dev/stdin <<EOF
           keycode  10 = Left     exclam 1 exclam onesuperior exclamdown      
           keycode  11 = Right    at 2 quotedbl twosuperior oneeighth
           keycode  12 = Up       numbersign 3 section threesuperior sterling
           keycode  13 = Down     dollar 4 dollar onequarter currency
           keycode  14 = Return   percent 5 percent onehalf threeeighths
           keycode  15 = Escape   asciicircum 6 ampersand notsign fiveeighths
EOF
elif [ "$orientation" = 'right' ]; then
	xrandr -o right
	xsetwacom set stylus rotate 1
	xsetwacom set eraser rotate 1
elif [ "$orientation" = 'inverted' ]; then
	xrandr -o inverted
	xsetwacom set stylus rotate 3
	xsetwacom set eraser rotate 3
fi

