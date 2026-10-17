local metadata =
{
    plugin =
    {
        format = "aar",

        manifest =
        {
            usesPermissions =
            {
                "android.permission.BLUETOOTH",
                "android.permission.BLUETOOTH_ADMIN",
                "android.permission.ACCESS_FINE_LOCATION",
                "android.permission.BLUETOOTH_SCAN",
                "android.permission.BLUETOOTH_CONNECT"
            }
        }
    }
}

return metadata