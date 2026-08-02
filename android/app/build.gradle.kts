plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // تحديد رقم إصدار الأندرويد كـ رقم مجرد وليس نص
    compileSdk = 35

    namespace = "com.example.maker_exampapers"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        // الصيغة الصحيحة والمتوافقة لتحديد jvmTarget بدون أخطاء
        jvmTarget = "17"
    }

    defaultConfig {
        // معرف التطبيق الخاص بك
        applicationId = "com.example.maker_exampapers"
        
        // الحد الأدنى لدعم الهواتف (رقم مجرد)
        minSdk = 21
        
        // الإصدار المستهدف (رقم مجرد ومتوافق مع الكاميرا)
        targetSdk = 35
        
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // إعدادات التوقيع الافتراضية للبناء التجريبي والمستقر
            signingConfig = signingConfigs.getByName("debug")
            
            // تفعيل التحسين لحل مشاكل المكتبات الخارجية مثل ML Kit
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
