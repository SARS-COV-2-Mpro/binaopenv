#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

echo "=== Installing dependencies ==="
apt-get update -qq
apt-get install -y \
  git cmake ninja-build pkg-config meson \
  libglib2.0-dev libssl-dev liblz4-dev \
  libjsoncpp-dev libcap-ng-dev libnl-3-dev \
  libnl-genl-3-dev uuid-dev libxml2-utils \
  dbus libsystemd-dev libasio-dev \
  libfmt-dev libtinyxml2-dev libdbus-1-dev 2>&1

echo "=== Creating openvpn user ==="
useradd --system --no-create-home --shell /usr/sbin/nologin --user-group openvpn 2>/dev/null || true

echo "=== Building gdbuspp v3 ==="
cd /tmp
rm -rf gdbuspp
git clone --depth=1 https://github.com/OpenVPN/gdbuspp.git
cd gdbuspp
git fetch --unshallow
git checkout v3
sed -i "s|subdir('tests')||" meson.build
meson setup --prefix=/usr build
ninja -C build
ninja -C build install
pkg-config --modversion gdbuspp

echo "=== Building openvpn3-linux v27 ==="
cd /tmp
rm -rf openvpn3-linux
git clone --depth=1 --branch v27 https://github.com/OpenVPN/openvpn3-linux.git
cd openvpn3-linux
git submodule update --init --depth=1
sed -i "s|subdir('distro/systemd')||" meson.build
sed -i "s|subdir('src/tests')||" meson.build
sed -i "s|subdir('session-watcher')||" src/python/meson.build
sed -i 's/if (dco)/if (false)/' src/client/core-client-netcfg.hpp
sed -i 's/^                dco\.reset();/\/\/ dco.reset();/' src/client/core-client-netcfg.hpp
meson setup --prefix=/usr --sysconfdir=/etc --localstatedir=/var -Ddco=disabled build
ninja -C build
ninja -C build install

echo "=== Setting up D-Bus ==="
mkdir -p /run/dbus
dbus-daemon --system --fork 2>/dev/null || true
sleep 1

echo "=== Patching D-Bus policies ==="
sed -i 's|<policy user="openvpn">|<policy user="root">\n    <allow own="net.openvpn.v3.log"/>\n    <allow send_destination="net.openvpn.v3.log"/>\n    <allow receive_sender="net.openvpn.v3.log"/>\n  </policy>\n\n  <policy user="openvpn">|' /usr/share/dbus-1/system.d/net.openvpn.v3.log.conf
sed -i 's|<policy user="openvpn">|<policy user="root">\n    <allow own="net.openvpn.v3.netcfg"/>\n    <allow send_destination="net.openvpn.v3.netcfg"/>\n    <allow receive_sender="net.openvpn.v3.netcfg"/>\n  </policy>\n\n  <policy user="openvpn">|' /usr/share/dbus-1/system.d/net.openvpn.v3.netcfg.conf
kill -HUP $(pidof dbus-daemon) 2>/dev/null || true

echo "=== Fixing CA cert ==="
python3 -c "
import ssl, socket, base64, re
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE
with socket.create_connection(('89.42.137.67', 443), timeout=10) as sock:
    with ctx.wrap_socket(sock) as ssock:
        der = ssock.getpeercert(binary_form=True)
pem = '-----BEGIN CERTIFICATE-----\n'
pem += base64.encodebytes(der).decode()
pem += '-----END CERTIFICATE-----\n'
ovpn = open('/workspaces/binaopenv/vpn.ovpn').read()
ovpn = re.sub(r'<ca>.*?</ca>', '<ca>\n' + pem + '</ca>', ovpn, flags=re.DOTALL)
open('/workspaces/binaopenv/vpn.ovpn','w').write(ovpn)
print('CA cert updated OK')
"

echo "=== Starting all services ==="
sudo /usr/libexec/openvpn3-linux/openvpn3-service-log --log-level 6 --service > /tmp/log-svc.log 2>&1 &
sleep 2
sudo /usr/libexec/openvpn3-linux/openvpn3-service-configmgr --log-level 6 > /tmp/configmgr.log 2>&1 &
sleep 2
sudo /usr/libexec/openvpn3-linux/openvpn3-service-sessionmgr --log-level 6 > /tmp/sessionmgr.log 2>&1 &
sleep 2
sudo /usr/libexec/openvpn3-linux/openvpn3-service-netcfg --log-level 6 --resolv-conf /etc/resolv.conf --redirect-method host-route --disable-capabilities --run-as-root > /tmp/netcfg.log 2>&1 &
sleep 2
touch /tmp/backendstart.log && chmod 777 /tmp/backendstart.log
su -s /bin/bash openvpn -c '/usr/libexec/openvpn3-linux/openvpn3-service-backendstart --log-level 6 >> /tmp/backendstart.log 2>&1 &'
sleep 2

echo "=== SETUP COMPLETE ==="
openvpn3 version
ps aux | grep openvpn3-service | grep -v grep
