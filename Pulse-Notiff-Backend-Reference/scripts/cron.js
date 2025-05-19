const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Setup cron jobs for the notification server
console.log('Setting up cron jobs for token recovery and maintenance...');

try {
  // Check if running on a system with crontab
  try {
    execSync('command -v crontab', { stdio: 'ignore' });
  } catch (error) {
    console.error('Crontab not available on this system. Please set up scheduled tasks manually.');
    console.log('For Windows, use Task Scheduler.');
    console.log('For macOS/Linux without crontab, use another scheduling mechanism.');
    
    // Write instructions to a file
    const instructions = `
# PULSE Notification Server - Scheduled Tasks

## Token Recovery (run daily)
Execute the following command daily to recover missing tokens:

\`\`\`
npm run recover-tokens
\`\`\`

## Windows Task Scheduler
1. Open Task Scheduler
2. Create a new Basic Task
3. Set the trigger to Daily
4. Action: Start a program
5. Program/script: npm
6. Arguments: run recover-tokens
7. Start in: ${process.cwd()}

## Linux/macOS (manual crontab)
Add this line to your crontab (crontab -e):

\`\`\`
0 2 * * * cd ${process.cwd()} && npm run recover-tokens >> logs/token-recovery.log 2>&1
\`\`\`
`;
    
    // Ensure logs directory exists
    const logsDir = path.join(process.cwd(), 'logs');
    if (!fs.existsSync(logsDir)) {
      fs.mkdirSync(logsDir);
    }
    
    fs.writeFileSync(path.join(process.cwd(), 'SCHEDULED_TASKS.md'), instructions);
    console.log('Created SCHEDULED_TASKS.md with instructions for manual setup');
    process.exit(0);
  }
  
  // Setup actual cron jobs if crontab is available
  const cronContent = `# PULSE Notification Server - Scheduled Tasks
# Run token recovery job daily at 2 AM
0 2 * * * cd ${process.cwd()} && npm run recover-tokens >> ${process.cwd()}/logs/token-recovery.log 2>&1
`;

  // Write to temporary file
  const tempFile = path.join(process.cwd(), 'temp-crontab');
  fs.writeFileSync(tempFile, cronContent);
  
  // Ensure logs directory exists
  const logsDir = path.join(process.cwd(), 'logs');
  if (!fs.existsSync(logsDir)) {
    fs.mkdirSync(logsDir);
  }

  // Attempt to install crontab
  try {
    execSync(`crontab ${tempFile}`, { stdio: 'inherit' });
    console.log('Successfully installed cron jobs');
  } catch (cronError) {
    console.error('Failed to install crontab. You may need to install it manually.');
    console.log(`Created crontab file at ${tempFile}`);
    console.log('To install manually run: crontab temp-crontab');
  }
  
  // Leave the temp file for manual installation if needed
  console.log('Cron setup completed');
} catch (error) {
  console.error('Error setting up cron jobs:', error);
  process.exit(1);
} 