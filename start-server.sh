#!/bin/bash

# Define the port to use
PORT=3000

# Check if the port is already in use
if lsof -i :$PORT > /dev/null 2>&1; then
  echo "Port $PORT is already in use. Attempting to kill the process..."
  
  # Get the PID of the process using the port
  PID=$(lsof -t -i :$PORT)
  
  if [ -n "$PID" ]; then
    echo "Killing process with PID: $PID"
    kill -9 $PID
    
    # Wait a moment to ensure the port is released
    sleep 1
    
    echo "Process killed successfully."
  else
    echo "Could not find PID for the process using port $PORT."
    exit 1
  fi
fi

# Check if we want to run in development or production mode
if [ "$1" == "dev" ]; then
  echo "Starting Next.js in development mode on port $PORT..."
  npm run dev -- -p $PORT
else
  echo "Starting Next.js in production mode on port $PORT..."
  
  # First build the static site
  npm run build
  
  # Check if express server script exists, if not create it
  if [ ! -f "server.js" ]; then
    echo "Creating Express server script for proper static file serving with route handling..."
    cat > server.js << 'EOL'
const express = require('express');
const path = require('path');
const fs = require('fs');
const app = express();
const PORT = process.env.PORT || 3000;

// Serve static files
app.use(express.static(path.join(__dirname, 'out')));

// For any route that doesn't match a static file, serve the appropriate HTML file
app.get('*', (req, res) => {
  let url = req.url;
  
  // Remove query parameters
  if (url.includes('?')) {
    url = url.split('?')[0];
  }
  
  // Ensure URL has trailing slash to match Next.js export format
  if (!url.endsWith('/') && !path.extname(url)) {
    url = `${url}/`;
  }
  
  // Default to index.html for root path
  if (url === '/') {
    return res.sendFile(path.resolve(__dirname, 'out', 'index.html'));
  }
  
  // Try to serve the route-specific HTML file
  const htmlPath = path.join(__dirname, 'out', url, 'index.html');
  
  // If HTML file exists for route, serve it
  if (fs.existsSync(htmlPath)) {
    return res.sendFile(htmlPath);
  }
  
  // Otherwise, serve the 404 page or fallback to index.html
  const notFoundPath = path.join(__dirname, 'out', '404.html');
  if (fs.existsSync(notFoundPath)) {
    return res.status(404).sendFile(notFoundPath);
  }
  
  // Last resort: serve the index.html (SPA fallback)
  return res.sendFile(path.resolve(__dirname, 'out', 'index.html'));
});

app.listen(PORT, () => {
  console.log(`Server running at http://localhost:${PORT}`);
  console.log(`Press Ctrl+C to stop the server`);
});
EOL
  fi
  
  # Check if express is installed, if not install it
  if ! npm list express >/dev/null 2>&1; then
    echo "Installing Express for server..."
    npm install --save express
  fi
  
  # Run the Express server
  echo "Starting Express server on port $PORT..."
  node server.js
fi 