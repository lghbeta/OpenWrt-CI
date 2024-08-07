#!/bin/bash

#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改默认WIFI名
sed -i "s/\.ssid=.*/\.ssid=$WRT_WIFI/g" $(find ./package/kernel/mac80211/ ./package/network/config/ -type f -name "mac80211.*")

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE
#修改默认时区
sed -i "s/timezone='.*'/timezone='CST-8'/g" $CFG_FILE
sed -i "/timezone='.*'/a\\\t\t\set system.@system[-1].zonename='Asia/Shanghai'" $CFG_FILE

if [[ $WRT_REPO == *"lede"* ]]; then
	LEDE_FILE=$(find ./package/lean/autocore/ -type f -name "index.htm")
	#修改默认时间格式
	sed -i 's/os.date()/os.date("%Y-%m-%d %H:%M:%S %A")/g' $LEDE_FILE
	#添加编译日期标识
	sed -i "s/(\(<%=pcdata(ver.luciversion)%>\))/\1 \/ $WRT_CI-$WRT_DATE/g" $LEDE_FILE
else
	#修改immortalwrt.lan关联IP
	sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
	#添加编译日期标识
	sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_CI-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")
fi

#配置文件修改
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo "$WRT_PACKAGE" >> ./.config
fi

#高通平台锁定512M内存
if [[ $WRT_TARGET == *"IPQ"* ]]; then
	echo "CONFIG_ATH11K_MEM_PROFILE_1G=n" >> ./.config
	echo "CONFIG_ATH11K_MEM_PROFILE_512M=y" >> ./.config
fi

#科学插件设置
if [[ $WRT_REPO == *"lede"* ]]; then
	echo "CONFIG_PACKAGE_luci-app-openclash=y" >> ./.config
	echo "CONFIG_PACKAGE_luci-app-passwall=y" >> ./.config
	echo "CONFIG_PACKAGE_luci-app-ssr-plus=y" >> ./.config
	echo "CONFIG_PACKAGE_luci-app-turboacc=y" >> ./.config
else
	echo "CONFIG_PACKAGE_luci=y" >> ./.config
	echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
#	echo "CONFIG_PACKAGE_luci-app-homeproxy=y" >> ./.config

	echo "CONFIG_PACKAGE_luci-app-passwall=y" >> ./.config
	echo "CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Rust_Client=n" >> ./.config
	echo "CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Rust_Server=n" >> ./.config
	echo "CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray_Geodata=y" >> ./.config
fi

#修改菜单
sed -i 's/"UPnP IGD & PCP\/NAT-PMP"/"UPnP"/g' $(find ./feeds/luci/applications/luci-app-upnp/ -type f -name "luci-app-upnp.json")

#添加初始运行脚本
mkdir -p files/etc/uci-defaults && cat << "EOF" > files/etc/uci-defaults/99-init-settings
#!/bin/bash

# Change source feeds
sed -i "s/^[^#].*qualcommax\/ipq60xx.*/#&/g" /etc/opkg/distfeeds.conf
sed -i "/nss_packages/d;/sqm_scripts_nss/d" /etc/opkg/distfeeds.conf

# Set default theme to luci-theme-argon
uci set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci

# Disable IPV6 ula prefix
#sed -i 's/^[^#].*option ula/#&/' /etc/config/network
#uci set network.globals.ula_prefix=''
#uci commit network

# Enable flow offloading
#uci set firewall.@defaults[0].flow_offloading=1
#uci set firewall.@defaults[0].flow_offloading_hw=1
#uci commit firewall

exit 0
EOF