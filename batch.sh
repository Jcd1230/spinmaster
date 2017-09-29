mkdir -p newspinners
for f in $1/*.png; 
do
	base=`basename $f`
	luajit masterpiece.lua $f 
	mv __tmp/final.gif newspinners/spinner_${base%.*}.gif
done
