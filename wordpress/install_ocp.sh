#!/bin/bash

set -e

display_help() {
  echo "Usage: install_ocp [OPTIONS]" >&2
  echo "Install and activate Object Cache Pro"
  echo
  echo "Mandatory arguments"
  echo "    -h, --help    Help Text"
  echo "    -t, --token   Object Cache License key"
  echo "    -r, --redis   Redis Host IP"
  echo "    --redis-pw    (optional) Redis password"
  echo "    --redis-db    (optional) Redis database"
  echo "    -p, --path    Path to wordpress installation"
}

if [ $# -eq 0 ] || [ $1 == '-h' ] || [ $1 == '--help' ]; then
  display_help
  exit 1
fi

while [ $# -gt 0 ] ; do
  case $1 in
    -t | --token) OCP_TOKEN="$2" ;;
    -r | --redis) REDIS_HOST="$2" ;;
    --redis-pw) REDIS_PW="$2" ;;
    --redis-db) REDIS_DB="$2" ;;
    -p | --path) WP_ROOT="$2" ;;
    -*) echo "Unknown argument '$1'."; exit 1 ;;
  esac
  shift
done

if [[ -z "${OCP_TOKEN}" ]]; then
  echo "Missing -t, --token."
  exit 1
fi

if [[ -z "${REDIS_HOST}" ]]; then
  echo "Missing -r, --redis."
  exit 1
fi

if [[ -z "${WP_ROOT}" ]]; then
  echo "Missing -p, --path."
  exit 1
fi

if [ ! -f "${WP_ROOT}/wp-config.php" ]; then
  echo "Invalid WP_ROOT: $WP_ROOT"
  exit 1
fi

if [[ -z "${REDIS_DB}" ]]; then
  REDIS_DB=0
fi

# Check that redis is configured properly
echo "Testing connection to Redis..."
if [[ -z "${REDIS_PW}" ]]; then  
  REDIS_CHECK=$(redis-cli -h $REDIS_HOST -n $REDIS_DB ping)
  if [[ ! $REDIS_CHECK == "PONG" ]]; then
    echo "Unable to connect to redis using $REDIS_HOST: $REDIS_CHECK"
    exit 1
  fi
else
  REDIS_CHECK=$(REDISCLI_AUTH=$REDIS_PW redis-cli -h $REDIS_HOST -n $REDIS_DB ping)
  if [[ ! $REDIS_CHECK == "PONG" ]]; then
    echo "Unable to connect to redis using $REDIS_HOST with password $REDIS_PW: $REDIS_CHECK"
    exit 1
  fi
fi

echo "...Connection Successful to ${REDIS_HOST}."
echo
echo "Downloading Object Cache Pro..."
# Download and install plugin
PLUGIN_FILE=$(mktemp)
curl -sSL --fail -o $PLUGIN_FILE "https://objectcache.pro/plugin/object-cache-pro.zip?token=${OCP_TOKEN}"
unzip $PLUGIN_FILE -d "$(wp plugin path --path=$WP_ROOT)"
rm $PLUGIN_FILE
echo "...Done."
echo

# I want to completely omit the password field if we're not using a password.
if [[ -z "${REDIS_PW}" ]]; then 
  OCP_CONFIG=$(cat <<EOF
[
    'token' => '${OCP_TOKEN}',
    'host' => '${REDIS_HOST}',
    'port' => 6379,
    'database' => ${REDIS_DB},
    'prefix' => 'db${REDIS_DB}:',
    'client' => 'relay',
    'shared' => false,
    'compression' => 'zstd',
    'serializer' => 'igbinary',
    'prefetch' => false,
    'split_alloptions' => false,
    'timeout' => 0.5,
    'read_timeout' => 0.5,
    'retries' => 3,
    'backoff' => 'smart',
]
EOF
)
else
  OCP_CONFIG=$(cat <<EOF
[
    'token' => '${OCP_TOKEN}',
    'host' => '${REDIS_HOST}',
    'password' => '${REDIS_PW}',
    'port' => 6379,
    'database' => ${REDIS_DB},
    'prefix' => 'db${REDIS_DB}:',
    'client' => 'relay',
    'shared' => false,
    'compression' => 'zstd',
    'serializer' => 'igbinary',
    'prefetch' => false,
    'split_alloptions' => false,
    'timeout' => 0.5,
    'read_timeout' => 0.5,
    'retries' => 3,
    'backoff' => 'smart',
]
EOF
)
fi

echo "Activating Object Cache Pro..."

wp config set --raw WP_REDIS_CONFIG "${OCP_CONFIG}" --path=$WP_ROOT
wp config set --raw WP_REDIS_DISABLED "getenv('WP_REDIS_DISABLED') ?: false" --path=$WP_ROOT

# Activate plugin
wp plugin activate object-cache-pro --path=$WP_ROOT

# Hot-swap object cache drop-in and flush
wp redis enable --force --path=$WP_ROOT

echo "...Done."

exit 0