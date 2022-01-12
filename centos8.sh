#!#!/bin/bash

w_log()
{
        time=`date "+%F %T"`
        echo "${time} $1" >> ${dir_work}/driver_compile.log
}

checkexit()
{
        if [ $? -ne "0" ]
        then
                w_log "Error: $1, code=$?"
                exit 1
        fi
}

os_version=8
dir_work=/root/make_driver
srpm=/root/shannon-module-3.4-3.2.src.rpm
dir_rpm=${dir_work}/rpm/
kernel_list=${dir_work}/kernel_list
kernel_tmp=${dir_work}/kernel_tmp
>${kernel_tmp}

#yum 环境配置
wget -O /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-8.repo
sed -i -e '/mirrors.cloud.aliyuncs.com/d' -e '/mirrors.aliyuncs.com/d' /etc/yum.repos.d/CentOS-Base.repo


w_log "第一部分：获取所有kernel信息"
all_os_version=(`curl -s https://mirrors.aliyun.com/centos/|grep 'class="link"><a href="'${os_version}.[0-9]|awk -F'[>/]' '{print $4}'|sort -t '.'  -k2 -n|tr "\n" "\t"`)
for i in ${all_os_version[@]}
do
        w_log "获取系统$i kernel包路径信息"
        if [ "$i" = "${all_os_version[-1]}" ];then
                url_main="https://mirrors.aliyun.com/centos/$i/BaseOS/x86_64/os/Packages/"
        else
                url_main="https://mirrors.aliyun.com/centos-vault/$i/BaseOS/x86_64/os/Packages/"
        fi
        w_log "下载系统$i kernel-devel开发包"
        for pack_name in `curl -s $url_main |egrep "kernel-devel" |awk -F"[<>]" '{print $5}'|sort -t "." -k4 -n`
        do
                wget -c -P $dir_rpm $url_main${pack_name}
	done
		w_log "下载系统$i kernel-devel开发包完成"
		
        for kernel_info in `curl -s $url_main |egrep "kernel-devel" |awk -F"[<>]" '{print $5}'|sort -t "." -k4 -n`
        do
                w_log "版本kernel ${kernel_info:13}信息收集"
		echo  $i ${kernel_info%.*} $url_update >>${kernel_tmp}
        done
done
awk '{print FNR,$0}' ${kernel_tmp} >${kernel_list}
w_log "第一部分:获取所有kernel信息完成"

w_log "第二部分：编译驱动"
w_log "清理历史开发环境"
rpm -qa|grep kernel-devel|xargs rpm -e
w_log "安装依赖包"
yum install -y gcc rpm-build ncurses-devel openssl-devel make elfutils-libelf-devel
checkexit
cat ${kernel_list} |awk '{print $3}'|while read line
do
        dir_ker=/usr/src/kernels/${line:13}
                if [ -d ${dir_ker} ];then
                                continue
                else
                #安装开发环境
                yum localinstall -y $dir_rpm/$line.rpm
                if [ $? -ne 0 ];then
                        echo "$line install failed!!"
                        exit 1
                fi
        fi
                #配置驱动
                set -e
                w_log "安装srpm包"
                rpm -ivh $srpm
                sed -i "s/%(uname -r)/${line:13}/g"  /root/rpmbuild/SPECS/shannon-driver.spec
                sed -i "/%build/a %define kdir ${dir_ker}" /root/rpmbuild/SPECS/shannon-driver.spec
                rpmbuild -bb /root/rpmbuild/SPECS/shannon-driver.spec
                #sed -i "50d" /root/rpmbuild/SPECS/shannon-driver.spec
                set +e
                w_log "kernel ${line:13}编译完成,驱动路径:/root/rpmbuild/RPMS/x86_64/"
done
w_log "驱动编译完成!"
