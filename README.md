# BT Battery Watch

BTBatteryWatch is a lightweight program for monitoring the battery level of Bluetooth devices on your Windows computer. The program does not rely on third-party software or drivers, runs in the background, and displays the battery level of the Bluetooth device every 30 minutes. I created BTBatteryWatch because I have several wireless mice, and the official software from mouse manufacturers has become intrusive and heavy with continuous background startup. I liked the idea of having a lightweight software that gives me the essential information: an overview of how much battery my mice have left before running out.

## Main features:
- Monitoring the battery level of the Bluetooth device with an icon that changes based on the battery level (to keep very light update the battery status every 10 minutes).
- Displaying the battery percentage when hovering over the icon in the System Tray.
- Disappearing pop-up notification (by pressing WINDOWS+SPACE simultaneously) to display the battery level and the name of the monitored device.
- Easy access to settings via the menu in the System Tray.
- Automatic program updates check.
- Ability to choose the Bluetooth device to monitor through the settings window.

**Reference Pictures**:

1.
![Icon System tray](src/IconinSystemtray.png)


2.
![Icon System tray Menu](src/IconSystemTrayMenu.png)


3.
![Mouse Over](src/MouseOver.png)


4.
![Settings](src/Settings.png)


5.
![Hotkeys](src/Windows+SpaceHotkeys.png)



## How to use:
1. **Initial configuration**: You will receive a warning that the configuration file is missing, and a window will open to create the configuration file. In this window, you have a `Search` button to press, and the software will search for all Bluetooth devices already registered/connected to the system and list them in the appropriate section. Simply select the name of your Bluetooth device that you want to monitor the battery and press the `Apply` button. Once the `Apply` button is pressed, you can close the window and reopen the program.
2. **Bluetooth battery monitoring**: Once configured, the program will start automatically and monitor the battery level of the specified Bluetooth device in the configuration file. Visual notifications will be displayed in the System Tray.
3. **Settings and updates**: If you want to change the device/mouse to monitor, you can easily access the program settings via the menu in the System Tray. Additionally, the program automatically checks for available updates and notifies you when a new version is available.

## Installation and use:
1. Download the latest version of the program from the [GitHub repository](https://github.com/Special-Niewbie/BTBatteryWatch/releases).
2. Run the installer that I have prepared.
3. Follow the instructions for the initial configuration.
4. The program will automatically start monitoring the battery level of the specified Bluetooth device.

## Important Note
BTBatteryWatch, being a very lightweight program and not relying on third-party libraries or software, can detect the battery percentage of your device if the Windows operating system sees the battery level of your device by default in the Bluetooth & devices Settings section.


## Donation
If you enjoy using this software and find it helpful and you have the possibility, please consider making a small donation to support the ongoing development of this and other projects. Your generosity is greatly appreciated!
PayPal:
 
[![Donate with PayPal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/paypalme/CrisDonate)

Ko-fi:
 
[![Donate with Ko-fi](https://www.ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/special_niewbie)
