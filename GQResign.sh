#!/bin/bash
#code by cs gq

#configure
#脚本存放目录
currentBashDir=""
#日志文件
logFile="log.txt"
#工作区域sub文件夹
workSpace="/workSpace"
#工作目录
workSpaceFile=""
#解压后app存放目录
unzipAppSpace="unzipIpa"
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

#error define
GQImporP12Fail="导入证书失败"
GQTooManyIpa="该文件夹中包含多个ipa，请只放置一个需重签名的ipa"
GQTooManyProvisitionFile="该文件夹中包含多个provisitionFile，请只放置一个需重签名的provisitionFile"
GQEntitlementsDealFail="Entitlements处理失败"
GQCerMatchProvisitionFail="所选证书与provisionfile的group不匹配"
GQUnZipFail="解压ipa失败"
GQCopyFail="拷贝失败"
GQFileLost="文件不存在"
GQChangePlistFail="修改info.plist失败"
GQSignFail="签名失败"
GQVerifySignFail="验证签名完整性失败"
GQZipAppFail="压缩app失败"

function msgActionShow()
{
    echo -e "\033[32m[执行]$1\033[0m"
    echo `date +%H:%M:%S.%s`"[执行]$1" >> "$logFile"
}
function msgErrorShow()
{
    echo -e "\033[31m[出错]$1\033[0m"
    echo `date +%H:%M:%S.%s`"[出错]$1" >> "$logFile"
}
function msgSucessShow()
{
    echo -e "\033[42;37m[成功]$1\033[0m"
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
        quitProgram "$file ""$GQFileLost"
    fi
}
function createWorkSpace()
{
    local currentFile=`pwd`
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

    mkdir "$workSpaceFile""$unzipAppSpace"   
    unzipAppSpace="$workSpaceFile""$unzipAppSpace"/

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
currentBashDir=$(cd "$(dirname "${BASH_SOURCE-$0}")"; pwd)
cd "$currentBashDir"

clear
# ================================================
msgSig "======================================="
msgSig "|            ___        ___            |"
msgSig "|           /          /   \\\\           |"
msgSig "|          ｜ ___     ｜   ｜          |"
msgSig "|          ｜   ｜    ｜   ｜          |"
msgSig "|           \\\\___/      \\\\___/\\\\          |"
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
p12File=$(getAppointFile "$currentBashDir" "p12")

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
        quitProgram "$GQImporP12Fail"
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
ipaFile=$(getAppointFile "$currentBashDir" "ipa")
if !([ -e "$ipaFile" ])
then
    quitProgram "$GQTooManyIpa"
fi

provisitionFile=$(getAppointFile "$currentBashDir" "mobileprovision")
if !([ -e "$provisitionFile" ])
then
    quitProgram "$GQTooManyProvisitionFile"
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
    quitProgram "$GQEntitlementsDealFail"
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
if [[ "$cerTeamId" != "$provisionFileTeamId"\)"" && "$cerType" != "Developer:" ]] 
then
    msgWarningShow "所选证书与provisionfile的group不匹配，是否继续？继续请按1"
    read -p "Enter your choice:"
    if [[ -z $REPLY || "$REPLY" != "1" ]]; then
        quitProgram "$GQCerMatchProvisitionFail"
    fi
fi
msgSucessShow "验证匹配性成功"

# 5.解压
msgActionShow "5.======解压ipa开始======"
(unzip -d "$unzipAppSpace" "$workSpaceIpaFile" >> "$logFile" 2>&1 ) || {
    quitProgram "$workSpaceIpaFile""$GQUnZipFail"
}
msgSucessShow "解压ipa成功"

#payload路径拼接
payloadPath="$unzipAppSpace"Payload
#获取app文件名
appFileName=$(getAppointFile "$payloadPath" "app")
#获取app的名称
appName=${appFileName%.*}

# 6.拷贝provisitionFile
msgActionShow "6.======拷贝""$workSpaceProvisionFile""-->""$unzipAppSpace""Payload/*.app/embedded.mobileprovision开始======"
#rm -rf Payload/*.app/_CodeSignature/
(cp "$workSpaceProvisionFile" "$unzipAppSpace"Payload/"$appName".app/embedded.mobileprovision >> "$logFile" 2>&1) || {
    quitProgram "$workSpaceProvisionFile""$GQCopyFail"
}
msgSucessShow "拷贝mobileprovision文件开始成功"

#拼接app的目录路径
appPath="$unzipAppSpace""Payload""/""$appFileName"

# List of plist keys used for reference to and from nested apps and extensions
NESTED_APP_REFERENCE_KEYS=(":WKCompanionAppBundleIdentifier" ":NSExtension:NSExtensionAttributes:WKAppBundleIdentifier")

for key in "${NESTED_APP_REFERENCE_KEYS[@]}"; do
# Check if Info.plist has a reference to another app or extension
    REF_BUNDLE_ID=$(PlistBuddy -c "Print ${key}" "$appPath/Info.plist" 2>/dev/null)
    if [ -n "$REF_BUNDLE_ID" ];
    then
        PlistBuddy -c "Set ${key} $bundleId" "$appPath/Info.plist"
    fi
done

# 7.修改info.plist
msgActionShow "7.======修改info.plist开始======"
if !([ -e "$unzipAppSpace"Payload/*.app/info.plist ])
then
    quitProgram "$infoPlist""$GQFileLost"
fi

(/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${bundleId}" "$unzipAppSpace"Payload/*.app/info.plist >> "$logFile" 2>&1)||{
    quitProgram "$GQChangePlistFail"
}
msgSucessShow "修改info.plist成功"

# 8.开始签名
msgActionShow "8.======签名开始======"

msgActionShow "8.1======剔除entitlementsPlist里面的黑字段======"

# Update in https://github.com/facebook/buck/commit/99c0fbc3ab5ecf04d186913374f660683deccdef
# Update in https://github.com/facebook/buck/commit/36db188da9f6acbb9df419dc1904315ab00c4e19

BLACKLISTED_KEYS=(\
    "com.apple.developer.icloud-container-development-container-identifiers" \
    "com.apple.developer.icloud-container-environment" \
    "com.apple.developer.icloud-container-identifiers" \
    "com.apple.developer.icloud-services" \
    "com.apple.developer.restricted-resource-mode" \
    "com.apple.developer.ubiquity-container-identifiers" \
    "com.apple.developer.ubiquity-kvstore-identifier" \
    "inter-app-audio" \
    "com.apple.developer.homekit" \
    "com.apple.developer.healthkit" \
    "com.apple.developer.in-app-payments" \
    "com.apple.developer.maps" \
    "com.apple.external-accessory.wireless-configuration"
)

for KEY in "${BLACKLISTED_KEYS[@]}"; do
    PlistBuddy -c "Delete $KEY" "$entitlementsPlist" 2>/dev/null
done

msgActionShow "8.2======Frameworks签名开始======"

resignPaths=`find "$appPath" -d -name *.app -o -name *.framework -o -name *.dylib -o -name *.appex -o -name *.so -o -name *.o -o -name *.vis -o -name *.pvr -o -name *.egg -o -name *.0`
IFS=$(echo -en "\n\b")
for bundle_item in ${resignPaths}
do
    if ([ -e "$bundle_item" ])
    then
        msgActionShow "$bundle_item 签名开始"
        (codesign -fs "${distributionCer}" --no-strict --entitlements="$entitlementsPlist" "$bundle_item" >> "$logFile" 2>&1) || {
            quitProgram "$GQSignFail"
        }
        (codesign -v "$bundle_item" >> "$logFile" 2>&1)||{
            quitProgram "$GQVerifySignFail"
        }
    fi
done

msgActionShow "8.3======App签名开始======"

(codesign -fs "${distributionCer}" --no-strict --entitlements="$entitlementsPlist" "$appPath" >> "$logFile" 2>&1) || {
    quitProgram "$GQSignFail"
}
msgSucessShow "签名成功"

# 9.验证文件是否签名完整
msgActionShow "9.======验证签名完整性开始======"
(codesign -v "$appPath" >> "$logFile" 2>&1)||{
    quitProgram "$GQVerifySignFail"
}
msgSucessShow "验证签名完整性成功"

# 10.压缩app文件
msgActionShow "10.======压缩app开始======"
cd "$unzipAppSpace"
#拼接输出文件
zipIpaFile="$outputFile""/"$appName"_resign.ipa"

(zip -qry "$zipIpaFile" -qry *) || {
    cd "$currentBashDir"
    quitProgram "$GQZipAppFail"
}
cd "$currentBashDir"

msgSucessShow "压缩app成功"
msgSucessShow "文件重签名ok了，赶快去试试吧"

# 11.删除工作目录 
quitProgram
