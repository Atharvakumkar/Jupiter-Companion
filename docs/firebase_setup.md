# Jupiter Companion — Firebase & Cloud Sync Architecture

## 1. Cloud-First, Local-First Philosophy

Jupiter Companion operates on a **Local-First, Offline-Durable** paradigm.
* Rides, maintenance records, fuel expenses, and parking locations are saved immediately to local SQLite.
* Even if the rider loses cellular connectivity in remote areas or basements, the application performs with 100% fidelity.
* When connectivity and authentication are present, records are synchronized into Google Cloud Firestore.

---

## 2. Firestore Document Hierarchy & Collection Paths

All user data is strictly partitioned by the authenticated user's unique UID:

```
users/{userId}
├── rides/{rideId}                      # Completed and historical ride sessions
├── maintenance/{recordId}              # Service and oil change receipts
├── fuelLogs/{fuelLogId}                # Petrol refuels, cost, and odometer readings
├── parkingLocations/{parkingId}        # Saved vehicle coordinates
└── settings/{documentId}               # Scooter profile and auto-record parameters
```

---

## 3. Strict Firestore Security Rules

To prevent data tampering or unauthorized cross-user reads/writes, apply the following Firestore Security Rules in the Firebase Console:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function checking authentication and ownership
    function isOwner(userId) {
      return request.auth != null && request.auth.uid == userId;
    }

    // User profile document
    match /users/{userId} {
      allow read, write: if isOwner(userId);

      // Ride documents
      match /rides/{rideId} {
        allow read, write: if isOwner(userId);
      }

      // Maintenance logs
      match /maintenance/{recordId} {
        allow read, write: if isOwner(userId);
      }

      // Fuel & expense receipts
      match /fuelLogs/{fuelLogId} {
        allow read, write: if isOwner(userId);
      }

      // Parking coordinates
      match /parkingLocations/{parkingId} {
        allow read, write: if isOwner(userId);
      }

      // User preferences
      match /settings/{documentId} {
        allow read, write: if isOwner(userId);
      }
    }
  }
}
```

---

## 4. Setup & Deployment Instructions

1. **Create Firebase Project:** Go to [Firebase Console](https://console.firebase.google.com/) and create a project named `jupiter-companion`.
2. **Enable Authentication:**
   * Enable **Email/Password** authentication provider.
   * Enable **Anonymous (Guest)** provider for offline-first testing.
3. **Enable Cloud Firestore:**
   * Create Firestore database in production mode.
   * Deploy the security rules above.
4. **Android App Registration:**
   * Register package name: `com.antigravity.jupitercompanion.jupiter_companion`.
   * Download `google-services.json` and place it in `android/app/`.
5. **Local Development Mode:**
   * If Firebase credentials are not supplied, Jupiter Companion operates seamlessly in local SQLite mode without crashing.

