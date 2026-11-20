# AGP 9's R8 is stricter and removes constructors of generated Room database
# implementations. Room instantiates those classes reflectively (via
# Room.openDatabaseHelper), and WorkManager opens a Room database at app startup
# through androidx.startup.InitializationProvider / WorkManagerInitializer.
# Without this rule the app crashes immediately on launch with:
#   RuntimeException: Failed to create an instance of androidx.work.impl.WorkDatabase
-keep class * extends androidx.room.RoomDatabase { <init>(); }

# Keep the WorkManager implementation reachable from its App Startup initializer.
-keep class androidx.work.impl.** { *; }
-keep class androidx.work.WorkManagerInitializer { *; }
