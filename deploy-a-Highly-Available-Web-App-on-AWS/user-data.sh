#!/bin/bash
set -e  # stop on any error

yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd

cat > /var/www/html/index.html <<EOF
<h1>Hello from Terraform Cluster!</h1>
<p>Environment: ${environment}</p>
<p>Server Port: ${server_port}</p>
<p>Hostname: $(hostname)</p>
<p>Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
EOF

# Configure Apache to listen on the correct port
sed -i "s/Listen 80/Listen ${server_port}/g" /etc/httpd/conf/httpd.conf
sed -i "s/:80/:${server_port}/g" /etc/httpd/conf.d/welcome.conf
systemctl restart httpd