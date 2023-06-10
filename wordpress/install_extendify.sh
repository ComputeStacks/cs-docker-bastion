#!/bin/bash

set -e

display_help() {
  echo "Usage: install_extendify [OPTIONS]" >&2
  echo "Install and activate Extendify"
  echo
  echo "Mandatory arguments"
  echo "    -h, --help    Help Text"
  echo "    --name        Partner Name"
  echo "    --logo        Logo URL"
  echo "    --license     License"
  echo "    --bgcolor     Background Color"
  echo "    --fgcolor     Text Color"
  echo "    --path        Path to wordpress installation"
}

if [ $# -eq 0 ] || [ $1 == '-h' ] || [ $1 == '--help' ]; then
  display_help
  exit 1
fi

while [ $# -gt 0 ] ; do
  case $1 in
    --name) PARTNER_NAME="$2" ;;
    --logo) PARTNER_LOGO="$2" ;;
    --license) SITE_LICENSE="$2" ;;
    --bgcolor) BG_COLOR="$2" ;;
    --fgcolor) FONT_COLOR="$2" ;;
    --path) WP_ROOT="$2" ;;
    -*) echo "Unknown argument '$1'."; exit 1 ;;
  esac
  shift
done

if [[ -z "${PARTNER_NAME}" ]]; then
  echo "Missing --name"
  exit 1
fi

if [[ -z "${PARTNER_LOGO}" ]]; then
  echo "Missing --logo"
  exit 1
fi

if [[ -z "${SITE_LICENSE}" ]]; then
  echo "Missing --license"
  exit 1
fi

if [[ -z "${BG_COLOR}" ]]; then
  BG_COLOR="#333333"
fi

if [[ -z "${FONT_COLOR}" ]]; then
  FONT_COLOR="#FFFFFF"
fi

if [[ -z "${WP_ROOT}" ]]; then
  echo "Missing -p, --path."
  exit 1
fi

if [ ! -f "${WP_ROOT}/wp-config.php" ]; then
  echo "Invalid WP_ROOT: $WP_ROOT"
  exit 1
fi


echo "Installing Extendify..."
wp plugin install extendify --activate --force --path=$WP_ROOT
wp theme install extendable --activate --force --path=$WP_ROOT
echo "...Done."
echo


echo "Configuring Extendify..."

mkdir -p $WP_ROOT/wp-content/mu-plugins
cp /opt/wordpress/extendify.php $WP_ROOT/wp-content/mu-plugins/extendify-cloudpress.php

sed -i "s/SET_PARTNER_LOGO/$PARTNER_LOGO/g" $WP_ROOT/wp-content/mu-plugins/extendify-cloudpress.php
sed -i "s/SET_PARTNER_NAME/$PARTNER_NAME/g" $WP_ROOT/wp-content/mu-plugins/extendify-cloudpress.php
sed -i "s/SET_SITE_LICENSE/$SITE_LICENSE/g" $WP_ROOT/wp-content/mu-plugins/extendify-cloudpress.php
sed -i "s/SET_BG_COLOR/$BG_COLOR/g" $WP_ROOT/wp-content/mu-plugins/extendify-cloudpress.php
sed -i "s/SET_FG_COLOR/$FONT_COLOR/g" $WP_ROOT/wp-content/mu-plugins/extendify-cloudpress.php

echo "...Done."

exit 0