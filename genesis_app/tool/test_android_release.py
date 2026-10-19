import unittest
from build_verified_android_release import validate_manifest

MANIFEST = '''<manifest xmlns:android="http://schemas.android.com/apk/res/android"
 package="com.worldo.ai" android:versionName="0.5.5" android:versionCode="61">
 <application><provider android:name="androidx.startup.InitializationProvider"
 android:authorities="com.worldo.ai.androidx-startup" android:exported="false">
 <meta-data android:name="androidx.lifecycle.ProcessLifecycleInitializer"
 android:value="androidx.startup"/></provider></application></manifest>'''


class ReleaseManifestTest(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_manifest(MANIFEST)['version_code'], '61')

    def test_missing_provider_or_lifecycle_fails(self):
        for name in ['androidx.startup.InitializationProvider',
                     'androidx.lifecycle.ProcessLifecycleInitializer']:
            with self.assertRaises(ValueError):
                validate_manifest(MANIFEST.replace(name, 'missing'))

    def test_exported_or_disabled_provider_fails(self):
        for xml in [MANIFEST.replace('exported="false"', 'exported="true"'),
                    MANIFEST.replace('<provider ', '<provider android:enabled="false" ')]:
            with self.assertRaises(ValueError):
                validate_manifest(xml)


if __name__ == '__main__':
    unittest.main()
