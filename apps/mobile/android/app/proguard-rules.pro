# Beta 4.9.1: R8 removed the no-argument constructor of WorkManager's Room
# database (WorkDatabase_Impl), which WorkManager makes by reflection when the
# app starts; 4.9 crashed on launch ("Unable to get provider
# androidx.startup.InitializationProvider"). Room databases and workers are
# made by reflection: keep their constructors.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
