# Jupiter Companion — Google Maps SDK Setup Guide

## 1. Why Google Maps Over Mappls

The TVS Connect default experience relies on Mappls, which riders report frequently lags, stutters, and fails to render live breadcrumb routes smoothly.

Jupiter Companion replaces this with the hardware-accelerated **Google Maps SDK for Android (`google_maps_flutter`)**, custom-styled with a dark automotive theme that matches modern motorcycle dashboard ergonomics.

---

## 2. Google Cloud Setup & Security Directives

### Step 1: Create Google Cloud Project
1. Open the [Google Cloud Console](https://console.cloud.google.com/).
2. Create or select a project (e.g., `jupiter-companion-prod`).
3. Ensure billing is enabled.

### Step 2: Enable Maps SDK for Android
1. Navigate to **APIs & Services > Library**.
2. Search for **Maps SDK for Android** and click **Enable**.

### Step 3: Create an Android-Restricted API Key
1. Go to **APIs & Services > Credentials**.
2. Click **Create Credentials > API key**.
3. Under **Set application restrictions**, choose **Android apps**.
4. Click **Add an item** and enter:
   * **Package name:** `com.antigravity.jupitercompanion.jupiter_companion`
   * **SHA-1 certificate fingerprint:**
     To obtain your debug SHA-1 fingerprint on your development machine:
     ```powershell
     keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
     ```
5. Under **API restrictions**, select **Restrict key** and check only **Maps SDK for Android**.
6. Save your API key.

---

## 3. Safe Configuration (No Secrets in Git)

Do not commit your raw Google Maps API key to Git. Jupiter Companion injects the key dynamically through Android Gradle manifests.

### Option A: Via `android/local.properties` (Recommended)
Add your API key to `android/local.properties` (which is already in `.gitignore`):
```properties
MAPS_API_KEY=AIzaSyYourActualGoogleMapsApiKeyHere
```

### Option B: Via Environment Variable
Set the environment variable before building:
```powershell
$env:GOOGLE_MAPS_API_KEY = "AIzaSyYourActualGoogleMapsApiKeyHere"
flutter build apk --debug
```

If neither is supplied, Gradle safely injects `DEFAULT_MAPS_API_KEY_PLACEHOLDER`, allowing compilation and offline GPS tracking to work without runtime crashes.

