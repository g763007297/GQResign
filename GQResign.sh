#!/bin/bash
#code by cs gq
logFile="log.txt"
#工作区域sub文件夹
workSpace="/workSpace"
#工作区域ipa存放地址
workSpaceIpaFile=""
#工作区域ProvisionFile存放地址
workSpaceProvisionFile=""
#输出文件夹
outputFile=""
#是否隐藏工作目录
hiddenWorkspace=1
#是否删除工作目录 非debug模式删除工作目录以及隐藏工作目录
Debug=0

function msgActionShow()
{
	echo -e "\033[42;37m[执行]$1\033[0m"
    echo `date +%H:%M:%S.%s`"[执行]$1" >> "$logFile"
}
function msgErrorShow()
{
	echo -e "\033[31m[出错]$1\033[0m"
    echo `date +%H:%M:%S.%s`"[出错]$1" >> "$logFile"
}
function msgSucessShow()
{
    echo -e "\033[32m[成功]$1\033[0m"
    echo `date +%H:%M:%S.%s`"[成功]$1" >> "$logFile"
}
function msgWarningShow()
{
    echo -e "\033[31m[提示]$1\033[0m"
    echo `date +%H:%M:%S.%s`"[提示]$1" >> "$logFile"
}
function msgSig()
{
    echo -e "\033[36m[签名]$1\033[0m"
}
function quitProgram()
{
    if ! [ -z $1 ]
    then
        msgErrorShow "失败原因:"$1
    fi
    
    if [ $Debug == 0 ]
    then
        rm -rf "$workSpaceFile"
    fi
    exit 1
}

function fileCheck()
{
    local file="$1"
    if ! ([ -f "$file" ]); then
        quitProgram "\""$file "\"文件不存在"
    fi
}
function createWorkSpace()
{
    currentFile=`pwd`
    workSpaceFile="$currentFile"$workSpace"/"
    outputFile=`pwd`"/output"

    #判断工作文件夹是否存在  存在就删除
    if ([ -d "$currentFile$workSpace" ]) 
    then
        rm -rf "$currentFile"$workSpace
    fi

    (mkdir  "$currentFile"$workSpace)&& {
        if [ $hiddenWorkspace == 1 ]
        then
            if [ $Debug == 0 ]
            then
                # chflags nohidden 显示指定隐藏文件
                chflags hidden "$currentFile"$workSpace
            fi
        fi
    }

    #判断输出文件夹是否存在 不存在就创建
    if ! ([ -d "$outputFile" ])
    then
        mkdir  "$outputFile"
    fi
    
    workSpaceIpaFile=$workSpaceFile"resign.ipa"
    workSpaceProvisionFile=$workSpaceFile"resign.mobileprovision"
    cp "$1" "$workSpaceIpaFile"
    cp "$2" "$workSpaceProvisionFile"
}

function componentsSeparatedByString()
{
    string="$1"
    OLD_IFS="$IFS"
    IFS=" "
    arr=($string)
    IFS="$OLD_IFS"
    echo ${arr[1]}
}

#获取文件下所有指定文件数
function getAppointFile()
{
    local var=0
    local chooseFile=""
    local currentPath=`pwd`
    cd "$1"
    array=`ls`
    for file in $array
    do 
        if [ -e "$file" ]
        then
            extension=${file##*.}
            test $extension = "$2"
            if [ $? == 0 ] 
            then
                chooseFile="$file"
                var=$((var+1))
            fi
        else
            local ss=0
        fi
    done
    cd "$currentPath"
    if [ $var -eq 1 ] 
    then
        echo "$chooseFile"
    else
        echo ""
    fi
}

#获取脚本文件目录
currentDir=$(cd "$(dirname "${BASH_SOURCE-$0}")"; pwd)
cd "$currentDir"

clear
# ================================================
msgSig "======================================="
msgSig "|            ___     ___              |"
msgSig "|           /   \\\\   /   \\\\             |"
msgSig "|          ｜       \\\\___              |"
msgSig "|          ｜           \\\\             |"
msgSig "|           \\\\___/   \\\\___/             |"
msgSig "======================================="

#获取当前系统版本 10.10以上的系统才是最佳使用该脚本的系统
curSysVersion=`sw_vers|grep ProductVersion|cut -d: -f2`
curSysVersion=${curSysVersion//./}
limitSysVersion="10.10.0"
limitSysVersion=${limitSysVersion//./}

if [ $curSysVersion -lt $limitSysVersion ]
then
    msgWarningShow "此程序最好在10.10.0以上使用"
    read -n1 -p "按任意键继续。。。"
    echo ""
fi

echo "===================="`date +%Y年%m月%d日`"====================" >> "$logFile"
######################项目参数配置
p12File=$(getAppointFile "$currentDir" "p12")

#提取P12文件中得证书名
if [ -n "$p12File" ]
then
    distributionCer=`openssl pkcs12 -password pass:"" -in $p12File -nodes 2>&1|grep friendlyName|head -n 1|sed 's/friendlyName://g'| grep -o "[^ ]\+\( \+[^ ]\+\)*"`
fi

#如果没有p12文件则选择证书
if [ -z "$distributionCer" ]
then
    inputFlag=1
else
#导入证书
    (security import $p12File -k ./login.keychain -P '' -T /usr/bin/codesign >> "$logFile" 2>&1)||{
        quitProgram "导入证书失败"
    }
    inputFlag=0
fi

while [ $inputFlag == 1 ]
do
    echo "证书如下，请选择一个（输入序号如：1）即可"
    /usr/bin/security find-identity -v -p codesigning
    cerList=`/usr/bin/security find-identity -v -p codesigning`
    read -p "Enter your choice:"
    if [ -z $REPLY ]
    then
        clear
        inputFlag=1
    else
        #如果输入小于证书count&&大于0就是ok的，否则继续
        distributionCer=`/usr/bin/security find-identity -v -p codesigning|grep $REPLY\)|cut -d \" -f2`
        if [ -z "$distributionCer" ] 
        then
            clear
            inputFlag=1
        else
            msgWarningShow "您选择的证书为:""$distributionCer"
            inputFlag=0
        fi
    fi
done

# 获取当前目录
# "$currentDir""/"
ipaFile=$(getAppointFile "$currentDir" "ipa")
if !([ -e "$ipaFile" ])
then
    quitProgram "该文件夹中包含多个ipa，请只放置一个需重签名的ipa"
fi

provisitionFile=$(getAppointFile "$currentDir" "mobileprovision")
if !([ -e "$provisitionFile" ])
then
    quitProgram "该文件夹中包含多个provisitionFile，请只放置一个需重签名的provisitionFile"
fi

# 1.文件验证
msgActionShow "1.======文件验证开始======"
fileCheck "$ipaFile"
fileCheck "$provisitionFile"
msgSucessShow "文件验证成功"

#配置工作空间
createWorkSpace "$ipaFile" "$provisitionFile"

# 2.解析成需要的entitlements.plist
msgActionShow "2.======处理entitlements开始======"
entitlementsPlist="$workSpaceFile"entitlements.plist

# defaults write ${entitlementsPlist} ${tmpDict}
# /usr/libexec/PlistBuddy -c "Set :dict ${tmpDict}" $entitlementsPlist
(/usr/libexec/PlistBuddy -x -c "print :Entitlements " /dev/stdin <<< $(security cms -D -i "$workSpaceProvisionFile") > "$entitlementsPlist") || {
    quitProgram "Entitlements处理失败"
}
msgSucessShow "Entitlements处理成功"

# 3.提取bundleId
if [ -z $bundleId ]
then
    msgActionShow "3.======提取bundleId开始======"
    applicationIdentifier=`/usr/libexec/PlistBuddy -c "Print :application-identifier " "$entitlementsPlist"`
    bundleId=${applicationIdentifier#*.}
    msgSucessShow "提取bundleId成功; BundleId: $bundleId "
fi

# 4.匹配provisionfile与证书  distribution的证书需要匹配，development的证书不需要匹配，因为如果是个人加到group中证书的group肯定不匹配，

msgActionShow "4.======开始验证provisionfile与证书是否匹配开始======"
cerType=`componentsSeparatedByString "$distributionCer"`
provisionFileTeamId=${applicationIdentifier%%.*}
cerTeamId=${distributionCer##*\(}
test $cerTeamId = "$provisionFileTeamId"\)""
if [[ "$cerTeamId" != "$provisionFileTeamId"\)"" && "$cerType" != "Developer:" ]] 
then
    msgWarningShow "所选证书与provisionfile的group不匹配，是否继续？继续请按1"
    read -p "Enter your choice:"
    if [[ -z $REPLY || "$REPLY" != "1" ]]; then
        quitProgram "所选证书与provisionfile的group不匹配"
    fi
fi
msgSucessShow "验证匹配性成功"

# 5.解压
msgActionShow "5.======解压ipa开始======"
(unzip -d "$workSpaceFile" "$workSpaceIpaFile" >> "$logFile" 2>&1 ) || {
    quitProgram \""$workSpaceIpaFile"\"解压ipa失败
}
msgSucessShow "解压ipa成功"

# 6.拷贝provisitionFile
msgActionShow "6.======拷贝""$workSpaceProvisionFile""-->""$workSpaceFile""Payload/*.app/embedded.mobileprovision开始======"
#rm -rf Payload/*.app/_CodeSignature/
(cp "$workSpaceProvisionFile" "$workSpaceFile"Payload/*.app/embedded.mobileprovision >> "$logFile" 2>&1) || {
    quitProgram \""$workSpaceProvisionFile"\"拷贝失败
}
msgSucessShow "拷贝mobileprovision文件开始成功"

# 7.修改info.plist
msgActionShow "7.======修改info.plist开始======"
if !([ -e "$workSpaceFile"Payload/*.app/info.plist ])
then
    quitProgram "$infoPlist""文件不存在"
fi

(/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${bundleId}" "$workSpaceFile"Payload/*.app/info.plist >> "$logFile" 2>&1)||{
    quitProgram "修改info.plist失败"
}
msgSucessShow "修改info.plist成功"

# 8.开始签名
msgActionShow "8.======签名开始======"

#payload路径拼接
payloadPath="$workSpaceFile"Payload
#获取app文件名
appName=$(getAppointFile "$payloadPath" "app")
#拼接app的目录路径
appPath="$workSpaceFile""Payload""/""$appName"
(codesign -fs "${distributionCer}" --no-strict --entitlements="$entitlementsPlist" "$appPath" >> "$logFile" 2>&1) || {
    quitProgram "签名失败"
}
msgSucessShow "签名成功"

# 9.验证文件是否签名完整
msgActionShow "9.======验证签名完整性开始======"
(codesign -v "$appPath" >> "$logFile" 2>&1)||{
    quitProgram "验证签名完整性失败"
}
msgSucessShow "验证签名完整性成功"

# 10.压缩app文件
msgActionShow "10.======压缩app开始======"
cd "$workSpaceFile"
#获取app的名称
temp=${appName%.*}
#拼接输出文件
zipIpaFile="$outputFile""/"$temp"_resign.ipa"

(zip -r "$zipIpaFile" Payload/ > /dev/null) || {
    cd ..
    quitProgram "压缩app失败"
}
cd ..

msgSucessShow "压缩app成功"
msgSucessShow "文件重签名ok了，赶快去试试吧"

# 11.删除工作目录 
quitProgram
