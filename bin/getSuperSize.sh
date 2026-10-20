#!/bin/bash
device_code=$(echo "$1" | tr -d '\r\n ' | tr '[:upper:]' '[:lower:]')

case $device_code in
	# Xiaomi 17 Ultra
	nezha) size=15300820992;;

	# Xiaomi Mix Fold 4
	myron) size=14495514624;;

	# Xiaomi 17 Series
	annibale | pudding | popsicle | pandora) size=13421772800;;

	# Xiaomi 15 Series / Redmi K70 Pro / K70 Ultra / Redmi Turbo 4 Pro
	haotian | xuanyuan | onyx | miro | klimt | dada | yudi | rodin | zorn | sheng | luming | manet | rothko) size=11811160064;;

	# POCO F6 / Redmi Note 14 Pro Series
	peridot | sea | ocean) size=10737418240;;

	# Xiaomi 13 / 14 / K60 Series / Note 12-13 Pro Series / Civi / Pad 6
	fuxi | nuwa | ishtar | socrates | babylon | marble | aurora | dew | garnet | vermeer | corot | duchamp | zircon | diting | plato | pipa | liuqin | mondrian | rembrandt | redwood | ruby | cupid | zeus | ingres | mayfly | unicorn | thor | rubens | matisse | shenzhou | houji | shennong) size=10021466112;;

	# Xiaomi 10 / 11 / POCO F3 / F4 / Note 10 Pro
	sweet | alioth | apollo | munch | zijin | taoyao | thyme | umi | cmi | cas) size=9663676416;;

	# Redmi Note 12 5G
	sunstone) size=9122611200;;

	# Redmi Note 14 4G / Note 14 Pro 4G
	obsidian | tanzanite) size=8053063680;;

	# Redmi Note 12/13 4G / 13C / 12C
	tapas | topaz | sapphire | sapphiren | gale | emerald | earth) size=7516192768;;

	# Redmi 12R
	sky) size=6979321856;;

	# Default cho tất cả các máy HyperOS hiện đại khác
	*) size=10021466112;;
esac

echo $size
