#!/bin/bash

# Script to open PostgreSQL port on the server
echo "Opening PostgreSQL port 5433 on the server..."

ssh -t -p 25222 deploy@142.132.239.135 << 'EOF'
# Check if ufw is installed and active
if command -v ufw &> /dev/null; then
    echo "Configuring UFW firewall..."
    sudo ufw allow 5433/tcp comment 'PostgreSQL Docker'
    sudo ufw reload
    echo "✅ Port 5433 opened in UFW"
else
    echo "UFW not found, checking iptables..."
    # Add iptables rule if ufw is not present
    sudo iptables -A INPUT -p tcp --dport 5433 -j ACCEPT -m comment --comment "PostgreSQL Docker"
    echo "✅ Port 5433 opened in iptables"
fi

# Verify the port is accessible
echo "Verifying port accessibility..."
if nc -zv localhost 5433 2>&1 | grep -q succeeded; then
    echo "✅ Port 5433 is accessible locally"
else
    echo "⚠️  Port 5433 might not be accessible yet. Docker container may need to fully start."
fi

echo ""
echo "PostgreSQL connection details:"
echo "================================"
echo "Host: 142.132.239.135"
echo "Port: 5433"
echo "Database: n8n_production"
echo "Username: n8n"
echo "Password: Blast?Errand82"
echo ""
echo "Connection string for external tools:"
echo "postgresql://n8n:Blast?Errand82@142.132.239.135:5433/n8n_production"
EOF