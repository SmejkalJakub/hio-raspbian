#!/bin/bash
set -eu

step() {
	_step_counter=$(( _step_counter + 1 ))
	# bold cyan
	printf '\n\033[1;36m%d) %s\033[0m\n' $_step_counter "$@" >&2
}

export LC_ALL='C.UTF-8'
export DEBIAN_FRONTEND='noninteractive'

if command -v pm2 >/dev/null 2>&1; then
step 'Start InfluxDB service: pm2'
sudo systemctl daemon-reload || true
sudo systemctl disable influxdb || true
sudo chown pi: -R /var/lib/influxdb
pm2 start /usr/bin/influxd --name influxdb -- -config /etc/influxdb/influxdb.conf
else
step 'Test InfluxDB service: systemd'
sudo systemctl daemon-reload
sudo systemctl enable influxdb
sudo systemctl start influxdb
fi

step 'Start the MQTT to InfluxDB service: pm2'
pm2 start `which python3` --name "mqtt2influxdb" -- `which mqtt2influxdb` -c /etc/hardwario/mqtt2influxdb.yml

step 'Start Grafana service'

if command -v pm2 >/dev/null 2>&1; then
sudo systemctl daemon-reload || true
sudo systemctl disable grafana-server || true
sudo systemctl stop grafana-server || true
pm2 start /usr/sbin/grafana-server --name grafana -- \
 -config=/etc/grafana/grafana.ini \
 -homepath /usr/share/grafana \
 cfg:default.paths.logs=/var/log/grafana \
 cfg:default.paths.data=/var/lib/grafana \
 cfg:default.paths.plugins=/var/lib/grafana/plugins \
 cfg:default.paths.provisioning=/etc/grafana/provisioning
else
step 'Test InfluxDB service: systemd'
sudo systemctl daemon-reload
sudo systemctl enable grafana-server
sudo systemctl start grafana-server

step 'Stop InfluxDB service: systemd'
sudo systemctl daemon-reload
sudo systemctl disable grafana-server
sudo systemctl stop grafana-server

fi

step 'Save the PM2 state (so it will start after reboot)'
pm2 save

IP=$(ifconfig | grep 'inet '| grep -v '127.0.0.1' | cut -d: -f2 | awk '{ print $2}')
echo "Grafana run on http://$IP:3000"
echo "Username: admin"
echo "Password: admin"
