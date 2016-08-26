# GQResign
ipa重签名(resign),只需一个证书的p12和一个mobileprovision文件就可以实现ipa的重签名

##（1）使用规则
###1.将GQResign.sh与你的mobileprovision文件和ipa文件放在同一个文件夹内。

###2.打开命令行，复制 chmod +x ,再将GQResign.sh拖入命令行里面，回车。

###3.继续将GQResign.sh拖入命令行内，回车，将会出现证书选择项，选择与你mobileprovision文件相匹配的证书，回车。

###4.等待数秒钟(视你的ipa资源文件的多少而定)。最后在output文件中就可以找到重签名成功地ipa

##（2）工程配置选项

###1.打开GQResign.sh 在头部有：

1.hiddenWorkspace:是否隐藏工作目录，默认设置1为隐藏。

2.Debug:测试模式；功能有：debug模式不会删除工作目录，也不会隐藏工作目录。

3.日志文件:在GQResign.sh同一目录下地log.txt，里面有详细的日志输出。

##（3）错误提示
###1."该文件夹中包含多个ipa，请只放置一个需重签名的ipa":文件夹内没放或者放了多个ipa文件，导致无法读取ipa文件；解决办法：只留一个需重签名的ipa文件。

###2."该文件夹中包含多个provisitionFile，请只放置一个需重签名的provisitionFile"：同上

###3."XX文件不存在"：该文件没有在GQResign.sh同一目录下。

###4."Entitlements处理失败":请前往log日志里面查看原因。

###5."所选证书与provisionfile的group不匹配":请检查证书和provisionfile是否匹配。

###6."XX解压ipa失败"：请确定ipa文件是否有损坏或者是否为ipa文件。

###7."XX拷贝失败"：请确认该文件是否在GQResign.sh同一目录下。

###8."修改info.plist失败":请确认文件目录是否有改变。

###9."签名失败":同第4点。

###10."验证签名完整性失败":请开启debug模式再次运行查看Payload文件是否存在。

###11."压缩app失败":同第10点。


####欢迎指出bug或者需要改善的地方，欢迎提出issues，或者联系qq：763007297， 我会及时的做出回应，觉得好用的话不妨给个star吧，你的每个star是我持续维护的强大动力。