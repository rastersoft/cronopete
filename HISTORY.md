## History of versions ##
* Version 3.26.1 (2017/08/26)
   * Added french translation
* Version 3.26.0 (2017/06/17)
   * Code cleanup that should fix the folders with odd names
* Version 3.25.0 (2017/04/04)
   * Now shows an error if trying to restore files without the backup disk
   * Updated Czech translation
* Version 3.24.0 (2017/02/10)
   * Now the restored file is the original one if there is no file with that name in the destination folder
   * Fixed the bookmarks and the path buttons in the restore interface
   * Now doesn't fail to restore files when the destination folder doesn't exist
* Version 3.23.0 (2017/02/10)
   * Now supports external drives with blank spaces in their name
* Version 3.22.0 (2016/11/10)
   * Now ensures that it doesn't die accidentally
   * Fixed a coding bug with internal IPC
* Version 3.21.0 (2015/12/05)
   * Now launches cronopete automagically when calling "restore" or "settings" icons from the launch menu (DBUS activation works again)
* Version 3.20.2 (2015/12/05)
   * Fixed again the cathegories in the .desktop files
* Version 3.20.1 (2015/12/05)
   * Fixed the cathegories in the .desktop files
* Version 3.20.0 (2015/09/10)
   * The multithreading race condition that made cronopete to crash randomly seems to be fixed
   * Removed deprecated GTK functions and properties
* Version 3.19.0 (2015/08/30)
   * Updated to Vala 0.26
   * Now uses the new Thread and Mutex syntax
   * Removed deprecated parameters in glade files
   * Now does all the string processing in the main thread
* Version 3.18.5 (2015/04/23)
   * Fixed a bug when detecting and listing hard disks
* Version 3.18.4 (2015/04/04)
   * Now uses only the UUID to find disks, to guarantee that the path used is the right one, even if it changes after launching cronopete
   * If the backup is enabled, cronopete will remount the disk if it is unmounted; if the backup is disabled, the disk can be removed
   * Now shows the GTK2 and GTK3 bookmarks in the Restore files window
   * The window asking for formating a disk now has the right size
   * Code cleanup
   * Removed deprecated GTK and GDK methods, like Gtk.Stock
* Version 3.18.3 (2015/04/03)
   * Migrated to UDisks2, to fix the problems when formating disks
* Version 3.18.2 (2015/04/03)
   * Now doesn't fail if, at startup, the hard disk isn't mounted
   * Now the main window doesn't get expanded if the status text is too big
* Version 3.18.1 (2015/04/03)
   * Fixed bugs when choosing a new disk
* Version 3.18.0 (2015/04/02)
   * Now searchs disks using the UUID
* Version 3.17.0 (2015/02/23)
   * Added Czech translation
   * Fixed the icon path
   * Allows to add several folders simultaneously
* Version 3.16.0 (2014/08/08)
   * Removed GTK2 support
   * Fixed the problems when mixing fullscreen and popup windows
* Version 3.15.3 (2013/12/14)
   * Now uses Gee 0.8
* Version 3.15.2 (2013/11/01)
   * Fixed galician translation
   * Removed the access to GTK from several threads
   * The CANCEL button when choosing a folder to (or not) backup now works
   * Now doesn't fail if pressing the ACCEPT button in the folder selection dialog without a folder selected
   * Now removes the wellcome message also if the user shows the configuration dialog
* Version 3.15.1 (2013/10/26)
   * Added a Welcome window
* Version 3.15.0 (2013/10/26)
   * Now doesn't hang when trying to set the partition type during disk formating
   * Changed the schema path from <i>apps.cronopete</i> to <i>org.rastersoft.cronopete</i> to be compliant with the Gnome rules (requires reconfiguration!!!)
   * Removed formating in ReiserFS; now only formats in Ext4, but still supports ReiserFS if formated manually by the user
   * Allows to show the non-usb disks directly from the interface
   * Now automounts the drive during launch
   * Build system migrated to Autovala+CMake
   * The code now uses the data automatically detected by Autovala
* Version 3.14.0 (2013/06/15)
   * Fixed the refresh bug when the timer line has to do a big jump.
* Version 3.13.0 (2013/06/09)
   * Fixed picture refresh bug in the file restoring system.
   * Fixed bug when formating external drives without partition table.
   * Removed several deprecated calls.
* Version 3.12.0 (2013/05/11)
   * Fixed a bug when trying to do a backup in a disk 100% full.
* Version 3.11.0 (2013/05/05)
   * Added a delay to avoid failure launch in Gnome Shell
   * Fixed return value in DRAW y EXPOSE-EVENT callbacks
* Version 3.10.0 (2013/01/27)
   * Fixed colors in symbolic icons.
* Version 3.9.0
   * Development version
* Version 3.8.0/1 (2013/01/20)
   * Fixed the scroll and the icons in the restore interface.
   * Fixed the background painting in the restore interface.
   * Added texts in the buttons of the restore interface.
   * Fixed compilation under Gtk2.
   * Added .deb packages for Gtk2.
* Version 3.7.0
   * Development version
* Version 3.6.0 (2012/12/21)
   * New restoring interface
   * Allows to use internal, non-removable drives (for testing)
   * Added new icons based in the -symbolic standard
   * Fixed the bug that made the restore window to grow each time the user changed the folder
   * Changed DBus bus from com.backup.cronopete to com.rastersoft.cronopete
* Version 3.5.0
   * Development version
* Version 3.4.6 (2012/10/28)
   * The configuration icon in Elementary will keep in the icon window
   * Removed sleep during startup because, with libappnotify, it's not needed
   * Now doesn't recreate the menu in the system bar each time something changes, but takes advantage of the capabilities of libappindicator (when used)
* Version 3.4.5 (2012/10/17)
   * Added D-Bus activation, to launch Cronopete when opening the configuration icon
   * CMake files modified to ensure that the autostart file is copied in the right place even when using a non-standard folder
   * Included the Vala CMake files
   * Added control files for PPA repositories with DEB packages for Ubuntu and Elementary OS
* Version 3.4.0 (2012/10/13)
   * Changed to CMake
   * Optional support for libappindicator
   * Simplified messages
   * New graphics
   * Added a progress bar for each file being restored
   * Now uses GConf to store the configuration
   * Now shows only external devices when asking for a drive
   * Added a .PLUG file for Elementary OS compatibility
   * Allows to show or hide the icon in the main bar
* Version 3.2.0 (2012/09/09)
   * Now compiles with Vala 0.16 (compatible with Debian)
   * Now new disks are formatted right, without returning a false error
   * Disks are also formatted when the access rights are incorrect
   * Added icons in windows and in window manager
   * Now it uses asynchronous calls when restoring files, instead of a thread
   * Reduced FPS in clock animation to reduce CPU usage
   * Added a "Restored ended successfully" message at the end of file restoration
   * Now also shows the date in the windows titlebar during file restoring
   * Updated animation during restoring to do it more efficient and smooth when not having GPU acceleration
* Version 3.1.0
   * Internal version
* Version 3.0.0 (2011/12/18)
   * Added support for GTK3 (GTK2 still supported)
   * Now keeps the file extension when restoring a file
* Version 2.3.0 (2011/12/02)
   * Added launcher from main menu, for systems without systray
   * Added Dbus remote control
   * Added icon cache to speed up the restoring interface
* Version 2.2.0 (2011/11/18)
   * It made a window capture when changing the restore view to list or icons. Fixed.
   * Fixed a core dump when unmounting the hard disk after launching the restore interface.
* Version 2.1.0 (2011/11/13)
   * Little modification to ensure that the zoom effect works better in slow computers.
* Version 2.0.0 (2011/11/11)
   * Added an interface to restore files from the backups.
* Version 1.3.0 (2011/10/23)
   * Cronopete closes when trying to format a NTFS-formated external drive. Fixed.
* Version 1.2.0 (2011/10/07)
   * Now keeps the modified date and time of the folders in the backups
* Version 1.1.0 (2011/09/17)
   * Allows to set the time interval between backups
   * Allows to choose the installation folder in the Makefile
   * Fixed a bug that produced a clock skew of five minutes; now the backups are done precisely at time
   * Now the popup menu is shown under the main bar, not over it
   * Some little adjustments in the interface
* Version 1.0.0 (2011/09/03)
   * First public version
