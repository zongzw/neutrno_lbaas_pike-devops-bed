	1. 准备一台nfs服务器，放置镜像文件：已经准备好：10.250.11.185:/root/downloads/CentOS-7-x86_64-Minimal-1810.iso
	2. IDRAC连接方法： 注意浏览器“允许弹出窗口”
		web浏览器打开 https://10.250.2.*
	    用户名密码： *******/****	
	3. Configuration -> virtual media -> image file path -> 填写nfs文件路径。  10.250.11.185:/root/downloads/CentOS-7-x86_64-Minimal-1810.iso
	4. Configuration ->virtual console -> launch virtual console. 
		a. 这里需要浏览器允许弹出窗口；如果无法打开console，切换别的浏览器试试，使用chrome OK。
		b. 选择Boot按钮 -> virtual CD/DVD/ISO
		c. 选择Power重启设备。 cold boot
	5. 重启后顺利进入系统引导安装界面（BIOS引导）。
    6. 在SYSTEM -> INSTALLATION DESTINATION 配置中，更改默认的磁盘大小比例，保证根目录最大化
        a. 选择 Local Standard Disks -> DELL PERC H330 Adp
        b. 选择 I will configure partitioning -> Done
        c. 选择已有的各个分区，依次点击"-" 删除 -> Client here to create them automatically
        d. 调整分区大小，将“/”调至最大（Desired Capacity写10000，系统会自动适配到最大），“/home” 保留20G即可 -> Update Settings -> Done -> Accept Changes
    7. Begin Installation
    8. Change Root Password
