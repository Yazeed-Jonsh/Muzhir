# SnakeYAML references java.beans APIs that are not available on Android.
# They are not used by the app at runtime, so suppress R8 missing-class warnings.
-dontwarn java.beans.BeanInfo
-dontwarn java.beans.FeatureDescriptor
-dontwarn java.beans.IntrospectionException
-dontwarn java.beans.Introspector
-dontwarn java.beans.PropertyDescriptor
