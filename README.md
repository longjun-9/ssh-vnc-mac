# 利用 SSH + VNC 实现远程内网Mac管理

## 背景
* SSH服务器地址为10.10.10.10，远程转发端口为3000，在Mac A上配置的别名为SSHServer。
* 远程内网Mac B的用户名为admin，且已安装HomeBrew。
* 本地Mac A已设置SSH免密登录，私钥位于 **~/.ssh/id_rsa**，配置文件位于 **~/.ssh/config**。

## 目标
Mac A可以通过在浏览器输入：**vnc://10.10.10.10:3000**，可以远程登录Mac B，并且重启Mac B之后，Mac A仍然可以远程登录Mac B。

## 步骤
1. 搭建SSH服务器，并开放远程转发端口3000；

2. Mac B开启屏幕共享；

3. Mac B 利用HomeBrew安装autossh；

4. 将**com.shell.autossh.plist**文件拷贝至Mac B的 **/Library/LaunchDaemons/** 文件夹（或者用**vi**命令创建文件然后拷贝内容也可以，权限不够请加**sudo**），然后修改其中的用户名；

5. 将startup文件夹拷贝至用户目录（~/）下，然后修改 **-fNR** 后面接的端口号3000为对应的端口号（此处为3000），修改**autossh.sh**中的用户名。关于startup中的shell脚本，如果无法双击运行，请修改脚本的打开方式为终端；如果没有可执行权限，请用**chmod +x**对所有用户添加可执行权限；

6. 双击运行startup中的**install_autossh.sh**，执行完成后窗口可关闭；

7. 重启Mac B，然后在登录Mac B之前使用Mac A的VNC远程登录Mac B，保存用户名和密码，并将连接保存为.vncloc文件；

8. 防止Mac B休眠。一般在电池设置或者是节能设置里面，具体细节请自行搜索。如果还是达不到效果，可以使用Amphetamine防止休眠（AppStore里面的精品推荐，免费应用，但是似乎有某些小bug，无限期默认设置修改后，会在重启后自动修正）；

## 说明
* 如果需要取消autossh开启启动，双击运行startup中的**uninstall_autossh.sh**。
* 如果ssh通道正确建立，可以使用**ps aux | grep ssh**来查看对应的进程是否已经起来，有两个是必要的，一个是autossh，一个是ssh。实际上是autossh开启了一个ssh的进程。
* 关于plist参数的作用，可以参考本文最后的连接。KeepAlive这里是一直保证进程在开启状态，即使杀死之后也会重启。
* linux上可用**netstat -anp | grep 20000**来查看20000端口占用的进程id，如果偶尔出现remote port forwarding failed for listen port 20000类似的错误，可以用词命令排除故障。
* 设置Amphetamine开机启动，启动后开启无限期会话，然后测试重启后的连通情况。以笔记本为例，内网Mac在不合上盖子的情况下，是可以在重启后连上的；如果合上盖子，有一定概率重启后连接失败，需要开盖。可能是Amphetamine无期限会话的“当关闭显示器时允许系统睡眠”选项会在重启后重新勾上的原因，所以最好不要合上盖子。

## 原理
1. 利用autossh建立Mac A到服务器的ssh通道，并保持通道不断开。
   autossh支持 **-M** 参数，如 **-M 20000** 就是将本地的20000端口映射到SSH服务器的20000端口，然后再将SSH服务器的20000端口映射到本地的20001（20000+1）。测试ssh通道是否开启时会使用20000端口发送测试数据包并使用20001监听返回数据包。注意⚠️，如果需要映射的端口不多，只有几个的话，autossh确实是最佳选择。但是如果需要映射大量端口，建议还是使用类似Ngrok的端口映射工具，毕竟这类工具拥有比较完善的管理功能。

2. 利用ssh端口转发，将内网IP映射到指定端口上。

   **autossh.sh**中，除了 **-M 20000** 和 **-f** 是autossh的参数外，其他参数都原样传递给ssh，其中-M 0表示不另开端口监测ssh，-f表示后台运行。auotssh是靠-M另开一个端口发送心跳数据包，由于新版ssh（protocol 2）内建了心跳功能，所以不再推荐另开端口。可以使用**ServerAliveInterval**和**ServerAliveCountMax**两个参数，ServerAliveInterval表示客户端向服务端每XX秒发送一次心跳数据包，ServerAliveCountMax表示如果发XX次还没响应，那么断开连接。我们也可以在服务端的/etc/ssh/sshd_config配置文件中添加ClientAliveInterval和ClientAliveCountMax参数后，重启sshd，表示由服务端向客户端发送心跳数据包。ExitOnForwardFailure表示ssh转发失败后，关闭连接并退出，这样autossh才能监测到错误并重启ssh连接。

## 问题
1. 如果**autossh.sh**使用-M 20000（目前是-M 0，并使用ssh内置心跳），而且多台内网Mac也是这样配置的，那么去掉-f参数，会在终端看到警告：remote port forwarding failed for listen port 20000，应该是远程的端口20000已被占用，所以映射到本地的20001会失败。但经过测试，似乎并不影响其功能。如果不想看到警告，可以每台内网Mac的-M参数都配置不同的端口号。

2. 如果把**autossh.sh**中的的参数全部直接写入**com.shell.autossh.plist**，即plist中可执行文件为 **/usr/local/bin/autossh**，则不能添加-f参数，具体原因不明。

3. 如果autossh以shell文件的形式运行，即plist中可执行文件为 **/Users/admin/startup/autossh.sh**，plist文件中如果指定了**StandardErrorPath**和**StandardOutPath**会生成日志文件，但始终为空。

4. 远程登录之后不能注销，否则就无法再次连接。

## 参考
1. [launchd.plist手册](https://www.manpagez.com/man/5/launchd.plist/)
2. [Launchd，如何在Mac上运行服务](https://yishanhe.net/dive-into-launchd/)
3. [Let your Mac phone home via SSH and launchd](https://blog.because-security.com/t/let-your-mac-phone-home-via-ssh-and-launchd/304)


