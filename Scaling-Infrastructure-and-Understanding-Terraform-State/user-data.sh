#!/bin/bash
set -e

# Update system
yum update -y
yum install -y httpd

# Configure httpd to listen on the correct port BEFORE starting
sed -i "s/Listen 80/Listen ${server_port}/g" /etc/httpd/conf/httpd.conf

# Update VirtualHost port if present
sed -i "s/<VirtualHost \*:80>/<VirtualHost *:${server_port}>/g" /etc/httpd/conf/httpd.conf

# Create custom index page showing instance identity
cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Terraform Day 5 - Load Balanced Cluster</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .container { max-width: 600px; margin: 0 auto; }
        .info { background: #f0f0f0; padding: 20px; border-radius: 5px; }
        h1 { color: #232f3e; }
        .highlight { color: #ff9900; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Hello from Terraform Day 5!</h1>
        <div class="info">
            <p><strong>Environment:</strong> <span class="highlight">${environment}</span></p>
            <p><strong>Server Port:</strong> <span class="highlight">${server_port}</span></p>
            <p><strong>Hostname:</strong> <span class="highlight">$(hostname -f)</span></p>
            <p><strong>Instance ID:</strong> <span class="highlight">$(curl -s http://169.254.169.254/latest/meta-data/instance-id)</span></p>
            <p><strong>Availability Zone:</strong> <span class="highlight">$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)</span></p>
            <p><strong>Local IP:</strong> <span class="highlight">$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)</span></p>
        </div>
        <p><em>Served by AWS Application Load Balancer</em></p>
    </div>
</body>
</html>
EOF

# Start and enable httpd
systemctl start httpd
systemctl enable httpd

echo "Setup complete at $(date)"