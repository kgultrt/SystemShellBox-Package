#!/system/bin/sh

echo "System Shell Box Initialization Program"
echo "Please wait..."

cd ~/../bin && /system/bin/chmod +x ./*
rm ~/.term/install.sh
chmod +x ~/.term/installer
cd ~/.term
./installer
rm ~/.term/installer

echo ""
echo "Done. This window will automatically close in 5 seconds."
sleep 5
exit