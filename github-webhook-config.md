# GitHub Webhook Configuration for Jenkins CI/CD Pipeline

## Setting up GitHub Webhook

1. Go to your GitHub repository for the URL shortener project
2. Click on "Settings" in the repository navigation
3. Select "Webhooks" from the left sidebar
4. Click "Add webhook"
5. Configure the webhook as follows:
   - Payload URL: `http://your-jenkins-server-url/github-webhook/`
   - Content type: `application/json`
   - Secret: (Optional, but recommended for security)
   - Which events would you like to trigger this webhook?: Select "Just the push event"
   - Active: Checked ✓
6. Click "Add webhook"

## Jenkins Configuration

1. In Jenkins, navigate to your pipeline job
2. Click "Configure"
3. In the "Build Triggers" section, check "GitHub hook trigger for GITScm polling"
4. Save the configuration

## Testing the Webhook

1. Make a small change to your repository
2. Commit and push to the main branch
3. Verify that the Jenkins pipeline is automatically triggered

## Troubleshooting

If the webhook is not triggering:

1. Check that your Jenkins server is accessible from the internet
2. Verify the webhook URL is correct
3. Check GitHub webhook delivery logs in repository settings
4. Examine Jenkins logs for any issues
