#!/bin/bash

# Shemet Dating Live App - Backend Deployment Script
# This script deploys Firebase Functions and Firestore Rules.

echo "🚀 Starting Backend Deployment..."

# 1. Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null
then
    echo "❌ Error: Firebase CLI is not installed. Install it with: npm install -g firebase-tools"
    exit 1
fi

# 2. Deploy Firestore Rules
echo "📄 Deploying Firestore Rules..."
firebase deploy --only firestore:rules

# 3. Deploy Cloud Functions
echo "⚙️ Deploying Cloud Functions (this may take a few minutes)..."
cd functions
npm run build
cd ..
firebase deploy --only functions

echo "✅ Deployment Complete!"
echo "Next steps: Check Firebase Console to ensure all functions are listed as 'Ready'."
