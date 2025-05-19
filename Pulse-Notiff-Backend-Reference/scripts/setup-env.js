const fs = require('fs');
const path = require('path');
const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

// Function to prompt for input
const prompt = (question) => {
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      resolve(answer);
    });
  });
};

// Main function
const main = async () => {
  console.log('PULSE Notification Server Setup');
  console.log('===============================');
  console.log('This script will help you set up your environment variables and service account key.');
  console.log('');
  
  // Check if .env file exists
  const envPath = path.join(__dirname, '..', '.env');
  const envExamplePath = path.join(__dirname, '..', '.env.example');
  
  if (!fs.existsSync(envExamplePath)) {
    console.error('Error: .env.example file not found. Please make sure you are running this script from the project root.');
    process.exit(1);
  }
  
  // Create .env file if it doesn't exist
  if (!fs.existsSync(envPath)) {
    fs.copyFileSync(envExamplePath, envPath);
    console.log('.env file created from .env.example');
  } else {
    console.log('.env file already exists');
  }
  
  // Check if service account key file exists
  const serviceAccountPath = path.join(__dirname, '..', 'service-account-key.json');
  
  if (!fs.existsSync(serviceAccountPath)) {
    console.log('');
    console.log('Service account key file not found.');
    console.log('You need to create a service account key in the Firebase Console:');
    console.log('1. Go to Firebase Console > Project Settings > Service Accounts');
    console.log('2. Click "Generate new private key"');
    console.log('3. Save the JSON file as service-account-key.json in the project root');
    
    const createNow = await prompt('Do you want to create a placeholder file now? (y/n): ');
    
    if (createNow.toLowerCase() === 'y') {
      const projectId = await prompt('Enter your Firebase project ID: ');
      const clientEmail = await prompt('Enter your service account client email: ');
      const privateKey = await prompt('Enter your service account private key (or press Enter to skip): ');
      
      const serviceAccountData = {
        type: 'service_account',
        project_id: projectId,
        private_key_id: '00000000000000000000000000000000',
        private_key: privateKey || '-----BEGIN PRIVATE KEY-----\nYOUR_PRIVATE_KEY_HERE\n-----END PRIVATE KEY-----\n',
        client_email: clientEmail,
        client_id: '000000000000000000000',
        auth_uri: 'https://accounts.google.com/o/oauth2/auth',
        token_uri: 'https://oauth2.googleapis.com/token',
        auth_provider_x509_cert_url: 'https://www.googleapis.com/oauth2/v1/certs',
        client_x509_cert_url: `https://www.googleapis.com/robot/v1/metadata/x509/${encodeURIComponent(clientEmail)}`
      };
      
      fs.writeFileSync(serviceAccountPath, JSON.stringify(serviceAccountData, null, 2));
      console.log('Placeholder service account key file created. Please replace it with your actual service account key.');
    } else {
      console.log('Please create the service account key file manually before running the server.');
    }
  } else {
    console.log('Service account key file already exists');
  }
  
  // Update .env file
  const updateEnv = await prompt('Do you want to update the .env file? (y/n): ');
  
  if (updateEnv.toLowerCase() === 'y') {
    const port = await prompt('Enter the port number (default: 3000): ');
    const databaseUrl = await prompt('Enter your Firebase database URL: ');
    
    let envContent = fs.readFileSync(envPath, 'utf8');
    
    if (port) {
      envContent = envContent.replace(/PORT=.*/, `PORT=${port}`);
    }
    
    if (databaseUrl) {
      envContent = envContent.replace(/FIREBASE_DATABASE_URL=.*/, `FIREBASE_DATABASE_URL=${databaseUrl}`);
    }
    
    fs.writeFileSync(envPath, envContent);
    console.log('.env file updated');
  }
  
  console.log('');
  console.log('Setup complete!');
  console.log('You can now run the server with:');
  console.log('npm run dev');
  
  rl.close();
};

main().catch(error => {
  console.error('Error:', error);
  rl.close();
  process.exit(1);
});
