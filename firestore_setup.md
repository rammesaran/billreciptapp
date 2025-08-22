# Firebase Firestore Setup for Shop Settings

To enable dynamic shop settings from Firebase Firestore, you need to create the following document structure:

## Collection: `settings`
### Document ID: `shop`

```json
{
  "shopNameTamil": "ரேவதி ஸ்டோர்",
  "shopNameEnglish": "Revathi Store",
  "addressTamil": "எண்.9, பச்சையப்பன் தெரு",
  "addressEnglish": "No.9, Pachaiappan Street",
  "cityTamil": "மேற்கு ஜாபர்கான்பேட்டை, சென்னை-2",
  "cityEnglish": "West Jafferkhanpet, Chennai-2",
  "phone": "8056115927",
  "headerText": "சேர்மன் சாமி துணை",
  "footerText1": "★பொருட்களை சரிபார்த்து எடுத்துக்கொள்ளவும்★",
  "footerText2": "கூகுள்பேயும்பார் 8925463455",
  "footerText3": "24 முதல்29விடுமுறை",
  "lastReceiptNumber": 3386,
  "lastUpdated": "2025-01-22T09:00:00.000Z"
}
```

## How to Set Up:

1. Go to your Firebase Console
2. Navigate to Firestore Database
3. Create a new collection called `settings`
4. Create a document with ID `shop`
5. Add the above fields with your shop's information

## Features:

- **Dynamic Updates**: Change shop details in Firestore and they'll be reflected in the app
- **Offline Support**: Settings are cached locally for offline use
- **Receipt Number Sync**: Receipt numbers are synchronized across devices
- **Bilingual Support**: Separate fields for Tamil and English text

## Benefits:

- No need to rebuild the app to change shop details
- Consistent branding across all receipts
- Easy management of footer messages and contact information
- Automatic receipt numbering with cloud backup
