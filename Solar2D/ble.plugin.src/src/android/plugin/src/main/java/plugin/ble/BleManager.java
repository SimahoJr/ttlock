package plugin.ble;

import android.Manifest;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothProfile;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanResult;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;

import com.ansca.corona.CoronaEnvironment;
import com.ansca.corona.CoronaLua;
import com.ansca.corona.CoronaRuntime;
import com.ansca.corona.CoronaRuntimeTask;
import com.ansca.corona.CoronaRuntimeTaskDispatcher;
import com.naef.jnlua.LuaState;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

public class BleManager {

    private static final int REQUEST_BLE_PERMISSIONS = 1001;

    /*
     * Bluetooth notification/indication Client Characteristic
     * Configuration Descriptor.
     */
    private static final UUID CCCD_UUID =
            UUID.fromString(
                    "00002902-0000-1000-8000-00805f9b34fb"
            );

    private final Context context;

    private final BluetoothManager bluetoothManager;

    private final BluetoothAdapter bluetoothAdapter;

    private BluetoothLeScanner bluetoothScanner;

    private ScanCallback scanCallback;

    private CoronaRuntimeTaskDispatcher runtimeDispatcher;

    private int listenerReference = CoronaLua.REFNIL;

    /*
     * Addresses of devices already reported during the current scan.
     */
    private final Set<String> discoveredDevices =
            new HashSet<>();

    /*
     * Connected BluetoothGatt objects.
     *
     * Key = deviceId/address
     */
    private final Map<String, BluetoothGatt> connections =
            new HashMap<>();

    /*
     * Cached discovered services.
     *
     * Key = deviceId/address
     */
    private final Map<String, List<BluetoothGattService>>
            servicesCache = new HashMap<>();

    /*
     * Only one asynchronous GATT operation should be in flight
     * at a time for a given connection.
     *
     * Key = deviceId/address
     *
     * Values:
     * "discover"
     * "read"
     * "write"
     * "subscribe"
     * "unsubscribe"
     */
    private final Map<String, String> pendingOperations =
            new HashMap<>();

    /*
     * Notification state.
     */
    private final Map<String, Set<String>>
            notificationCharacteristics =
            new HashMap<>();

    public BleManager() {

        Context activityContext =
                CoronaEnvironment.getCoronaActivity();

        if (activityContext != null) {

            context =
                    activityContext.getApplicationContext();

        } else {

            context = null;
        }

        if (context != null) {

            bluetoothManager =
                    (BluetoothManager)
                            context.getSystemService(
                                    Context.BLUETOOTH_SERVICE
                            );

        } else {

            bluetoothManager = null;
        }

        if (bluetoothManager != null) {

            bluetoothAdapter =
                    bluetoothManager.getAdapter();

        } else {

            bluetoothAdapter = null;
        }
    }

    // ---------------------------------------------------------------------
    // Initialization
    // ---------------------------------------------------------------------

    public void initialize(
            LuaState luaState,
            int listenerRef
    ) {

        listenerReference = listenerRef;

        runtimeDispatcher =
                new CoronaRuntimeTaskDispatcher(luaState);
    }

    // ---------------------------------------------------------------------
    // Basic state
    // ---------------------------------------------------------------------

    public boolean isSupported() {

        return bluetoothAdapter != null;
    }

    public boolean isEnabled() {

        if (bluetoothAdapter == null) {
            return false;
        }

        try {

            return bluetoothAdapter.isEnabled();

        } catch (SecurityException e) {

            return false;
        }
    }

    public boolean hasPermission() {

        if (context == null) {
            return false;
        }

        if (Build.VERSION.SDK_INT >=
                Build.VERSION_CODES.S) {

            return context.checkSelfPermission(
                    Manifest.permission.BLUETOOTH_SCAN
            ) == PackageManager.PERMISSION_GRANTED
                    &&
                    context.checkSelfPermission(
                            Manifest.permission.BLUETOOTH_CONNECT
                    ) == PackageManager.PERMISSION_GRANTED;

        } else {

            return context.checkSelfPermission(
                    Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED;
        }
    }

    public void requestPermission() {

        if (context == null) {
            return;
        }

        if (Build.VERSION.SDK_INT >=
                Build.VERSION_CODES.S) {

            CoronaEnvironment
                    .getCoronaActivity()
                    .requestPermissions(
                            new String[] {
                                    Manifest.permission.BLUETOOTH_SCAN,
                                    Manifest.permission.BLUETOOTH_CONNECT
                            },
                            REQUEST_BLE_PERMISSIONS
                    );

        } else {

            CoronaEnvironment
                    .getCoronaActivity()
                    .requestPermissions(
                            new String[] {
                                    Manifest.permission.ACCESS_FINE_LOCATION
                            },
                            REQUEST_BLE_PERMISSIONS
                    );
        }
    }

    // ---------------------------------------------------------------------
    // Scan
    // ---------------------------------------------------------------------

    public boolean startScan() {

        if (bluetoothAdapter == null) {

            dispatchError(
                    "Bluetooth is not supported."
            );

            return false;
        }

        if (!isEnabled()) {

            dispatchError(
                    "Bluetooth is disabled."
            );

            return false;
        }

        if (!hasPermission()) {

            dispatchError(
                    "BLE permission has not been granted."
            );

            return false;
        }

        try {

            bluetoothScanner =
                    bluetoothAdapter
                            .getBluetoothLeScanner();

            if (bluetoothScanner == null) {

                dispatchError(
                        "BLE scanner is unavailable."
                );

                return false;
            }

            if (scanCallback != null) {

                bluetoothScanner.stopScan(
                        scanCallback
                );
            }

            synchronized (discoveredDevices) {

                discoveredDevices.clear();
            }

            scanCallback =
                    new ScanCallback() {

                        @Override
                        public void onScanResult(
                                int callbackType,
                                ScanResult result
                        ) {

                            handleScanResult(result);
                        }

                        @Override
                        public void onBatchScanResults(
                                List<ScanResult> results
                        ) {

                            if (results == null) {
                                return;
                            }

                            for (ScanResult result :
                                    results) {

                                handleScanResult(result);
                            }
                        }

                        @Override
                        public void onScanFailed(
                                int errorCode
                        ) {

                            dispatchScanError(
                                    errorCode
                            );
                        }
                    };

            bluetoothScanner.startScan(
                    scanCallback
            );

            return true;

        } catch (SecurityException e) {

            dispatchError(
                    "BLE permission denied: "
                            + e.getMessage()
            );

            return false;

        } catch (Exception e) {

            dispatchError(
                    "Unable to start BLE scan: "
                            + e.getMessage()
            );

            return false;
        }
    }

    public void stopScan() {

        if (bluetoothScanner == null
                || scanCallback == null) {

            return;
        }

        try {

            bluetoothScanner.stopScan(
                    scanCallback
            );

        } catch (SecurityException ignored) {
        }

        scanCallback = null;
    }

    private void handleScanResult(
            final ScanResult result
    ) {

        if (result == null
                || result.getDevice() == null) {

            return;
        }

        final BluetoothDevice device =
                result.getDevice();

        final String address =
                device.getAddress();

        if (address == null) {
            return;
        }

        synchronized (discoveredDevices) {

            if (discoveredDevices.contains(address)) {
                return;
            }

            discoveredDevices.add(address);
        }

        final int rssi =
                result.getRssi();

        String deviceName = null;

        try {

            deviceName =
                    device.getName();

        } catch (SecurityException ignored) {
        }

        final String finalDeviceName =
                deviceName;

        dispatchDeviceFound(
                address,
                finalDeviceName,
                rssi
        );
    }

    // ---------------------------------------------------------------------
    // Connect
    // ---------------------------------------------------------------------

    public boolean connect(
            final String deviceId
    ) {

        if (deviceId == null
                || deviceId.length() == 0) {

            dispatchConnectionError(
                    deviceId,
                    "Device ID is required."
            );

            return false;
        }

        if (bluetoothAdapter == null) {

            dispatchError(
                    "Bluetooth is not supported."
            );

            return false;
        }

        if (!isEnabled()) {

            dispatchError(
                    "Bluetooth is disabled."
            );

            return false;
        }

        if (!hasPermission()) {

            dispatchError(
                    "BLE permission has not been granted."
            );

            return false;
        }

        try {

            final BluetoothDevice device =
                    bluetoothAdapter.getRemoteDevice(
                            deviceId
                    );

            if (device == null) {

                dispatchConnectionError(
                        deviceId,
                        "Device not found."
                );

                return false;
            }

            /*
             * Close any previous connection for this device.
             */
            BluetoothGatt oldGatt =
                    connections.remove(deviceId);

            if (oldGatt != null) {

                try {
                    oldGatt.disconnect();
                } catch (Exception ignored) {
                }

                try {
                    oldGatt.close();
                } catch (Exception ignored) {
                }
            }

            servicesCache.remove(deviceId);
            pendingOperations.remove(deviceId);
            notificationCharacteristics.remove(
                    deviceId
            );

            BluetoothGattCallback callback =
                    new BluetoothGattCallback() {

                        @Override
                        public void onConnectionStateChange(
                                BluetoothGatt gatt,
                                int status,
                                int newState
                        ) {

                            if (status !=
                                    BluetoothGatt.GATT_SUCCESS) {

                                connections.remove(
                                        deviceId
                                );

                                servicesCache.remove(
                                        deviceId
                                );

                                pendingOperations.remove(
                                        deviceId
                                );

                                notificationCharacteristics
                                        .remove(deviceId);

                                dispatchConnectionError(
                                        deviceId,
                                        "GATT connection failed. "
                                                + "status="
                                                + status
                                );

                                try {
                                    gatt.close();
                                } catch (Exception ignored) {
                                }

                                return;
                            }

                            if (newState ==
                                    BluetoothProfile
                                            .STATE_CONNECTED) {

                                connections.put(
                                        deviceId,
                                        gatt
                                );

                                servicesCache.remove(
                                        deviceId
                                );

                                dispatchConnected(
                                        deviceId
                                );

                            } else if (
                                    newState ==
                                            BluetoothProfile
                                                    .STATE_DISCONNECTED
                            ) {

                                connections.remove(
                                        deviceId
                                );

                                servicesCache.remove(
                                        deviceId
                                );

                                pendingOperations.remove(
                                        deviceId
                                );

                                notificationCharacteristics
                                        .remove(deviceId);

                                try {
                                    gatt.close();
                                } catch (Exception ignored) {
                                }

                                dispatchDisconnected(
                                        deviceId
                                );
                            }
                        }

                        @Override
                        public void onServicesDiscovered(
                                BluetoothGatt gatt,
                                int status
                        ) {

                            clearPending(
                                    deviceId,
                                    "discover"
                            );

                            if (status !=
                                    BluetoothGatt.GATT_SUCCESS) {

                                dispatchServiceError(
                                        deviceId,
                                        "Service discovery failed. "
                                                + "status="
                                                + status
                                );

                                return;
                            }

                            List<BluetoothGattService>
                                    services =
                                    gatt.getServices();

                            servicesCache.put(
                                    deviceId,
                                    services
                            );

                            dispatchServicesDiscovered(
                                    deviceId,
                                    services
                            );
                        }

                        @Override
                        public void onCharacteristicRead(
                                BluetoothGatt gatt,
                                BluetoothGattCharacteristic
                                        characteristic,
                                int status
                        ) {

                            clearPending(
                                    deviceId,
                                    "read"
                            );

                            if (status !=
                                    BluetoothGatt.GATT_SUCCESS) {

                                dispatchReadError(
                                        deviceId,
                                        characteristic,
                                        "Characteristic read failed. "
                                                + "status="
                                                + status
                                );

                                return;
                            }

                            byte[] value =
                                    characteristic.getValue();

                            dispatchCharacteristicRead(
                                    deviceId,
                                    characteristic,
                                    value
                            );
                        }

                        /*
                         * Android 13 / API 33 callback.
                         */
                        @Override
                        public void onCharacteristicRead(
                                BluetoothGatt gatt,
                                BluetoothGattCharacteristic
                                        characteristic,
                                byte[] value,
                                int status
                        ) {

                            clearPending(
                                    deviceId,
                                    "read"
                            );

                            if (status !=
                                    BluetoothGatt.GATT_SUCCESS) {

                                dispatchReadError(
                                        deviceId,
                                        characteristic,
                                        "Characteristic read failed. "
                                                + "status="
                                                + status
                                );

                                return;
                            }

                            dispatchCharacteristicRead(
                                    deviceId,
                                    characteristic,
                                    value
                            );
                        }

                        @Override
                        public void onCharacteristicWrite(
                                BluetoothGatt gatt,
                                BluetoothGattCharacteristic
                                        characteristic,
                                int status
                        ) {

                            clearPending(
                                    deviceId,
                                    "write"
                            );

                            if (status !=
                                    BluetoothGatt.GATT_SUCCESS) {

                                dispatchWriteError(
                                        deviceId,
                                        characteristic,
                                        "Characteristic write failed. "
                                                + "status="
                                                + status
                                );

                                return;
                            }

                            dispatchCharacteristicWritten(
                                    deviceId,
                                    characteristic,
                                    false
                            );
                        }

                        @Override
                        public void onCharacteristicChanged(
                                BluetoothGatt gatt,
                                BluetoothGattCharacteristic
                                        characteristic
                        ) {

                            byte[] value =
                                    characteristic.getValue();

                            dispatchCharacteristicChanged(
                                    deviceId,
                                    characteristic,
                                    value
                            );
                        }

                        /*
                         * Android 13 / API 33 callback.
                         */
                        @Override
                        public void onCharacteristicChanged(
                                BluetoothGatt gatt,
                                BluetoothGattCharacteristic
                                        characteristic,
                                byte[] value
                        ) {

                            dispatchCharacteristicChanged(
                                    deviceId,
                                    characteristic,
                                    value
                            );
                        }

                        @Override
                        public void onDescriptorWrite(
                                BluetoothGatt gatt,
                                BluetoothGattDescriptor
                                        descriptor,
                                int status
                        ) {

                            String operation =
                                    pendingOperations.get(
                                            deviceId
                                    );

                            if (status !=
                                    BluetoothGatt.GATT_SUCCESS) {

                                clearPending(
                                        deviceId,
                                        operation
                                );

                                dispatchNotificationError(
                                        deviceId,
                                        descriptor,
                                        "Descriptor write failed. "
                                                + "status="
                                                + status
                                );

                                return;
                            }

                            BluetoothGattCharacteristic
                                    characteristic =
                                    descriptor
                                            .getCharacteristic();

                            clearPending(
                                    deviceId,
                                    operation
                            );

                            boolean enabled =
                                    "subscribe".equals(
                                            operation
                                    );

                            if (enabled) {

                                addNotificationState(
                                        deviceId,
                                        characteristic
                                );

                            } else if (
                                    "unsubscribe".equals(
                                            operation
                                    )
                            ) {

                                removeNotificationState(
                                        deviceId,
                                        characteristic
                                );
                            }

                            dispatchNotificationStateChanged(
                                    deviceId,
                                    characteristic,
                                    enabled
                            );
                        }
                    };

            BluetoothGatt gatt;

            if (Build.VERSION.SDK_INT >=
                    Build.VERSION_CODES.M) {

                gatt = device.connectGatt(
                        context,
                        false,
                        callback,
                        BluetoothDevice.TRANSPORT_LE
                );

            } else {

                gatt = device.connectGatt(
                        context,
                        false,
                        callback
                );
            }

            if (gatt == null) {

                dispatchConnectionError(
                        deviceId,
                        "Unable to create BluetoothGatt."
                );

                return false;
            }

            /*
             * Store immediately because Android may complete
             * the connection asynchronously.
             */
            connections.put(
                    deviceId,
                    gatt
            );

            return true;

        } catch (SecurityException e) {

            dispatchConnectionError(
                    deviceId,
                    "BLE permission denied."
            );

            return false;

        } catch (Exception e) {

            dispatchConnectionError(
                    deviceId,
                    safeMessage(e)
            );

            return false;
        }
    }

    public void disconnect(
            String deviceId
    ) {

        if (deviceId == null) {
            return;
        }

        BluetoothGatt gatt =
                connections.remove(deviceId);

        servicesCache.remove(deviceId);
        pendingOperations.remove(deviceId);
        notificationCharacteristics.remove(
                deviceId
        );

        if (gatt == null) {
            return;
        }

        try {

            gatt.disconnect();

        } catch (Exception ignored) {
        }

        /*
         * Do not immediately close here. The callback will receive
         * STATE_DISCONNECTED and close it.
         */
    }

    // ---------------------------------------------------------------------
    // Service discovery
    // ---------------------------------------------------------------------

    public boolean discoverServices(
            final String deviceId
    ) {

        BluetoothGatt gatt =
                getConnection(
                        deviceId
                );

        if (gatt == null) {
            return false;
        }

        if (!beginOperation(
                deviceId,
                "discover"
        )) {

            return false;
        }

        try {

            boolean started =
                    gatt.discoverServices();

            if (!started) {

                clearPending(
                        deviceId,
                        "discover"
                );

                dispatchServiceError(
                        deviceId,
                        "Unable to start service discovery."
                );
            }

            return started;

        } catch (SecurityException e) {

            clearPending(
                    deviceId,
                    "discover"
            );

            dispatchServiceError(
                    deviceId,
                    "BLE permission denied."
            );

            return false;

        } catch (Exception e) {

            clearPending(
                    deviceId,
                    "discover"
            );

            dispatchServiceError(
                    deviceId,
                    safeMessage(e)
            );

            return false;
        }
    }

    // ---------------------------------------------------------------------
    // Get cached services
    // ---------------------------------------------------------------------

    public List<BluetoothGattService> getServices(
            String deviceId
    ) {

        return servicesCache.get(deviceId);
    }

    public List<BluetoothGattCharacteristic>
    getCharacteristics(
            String deviceId,
            String serviceUuid
    ) {

        BluetoothGattService service =
                findService(
                        deviceId,
                        serviceUuid
                );

        if (service == null) {
            return null;
        }

        return service.getCharacteristics();
    }

    // ---------------------------------------------------------------------
    // Read
    // ---------------------------------------------------------------------

    public boolean read(
            final String deviceId,
            final String serviceUuid,
            final String characteristicUuid
    ) {

        BluetoothGatt gatt =
                getConnection(deviceId);

        if (gatt == null) {
            return false;
        }

        BluetoothGattCharacteristic characteristic =
                findCharacteristic(
                        deviceId,
                        serviceUuid,
                        characteristicUuid
                );

        if (characteristic == null) {

            dispatchReadError(
                    deviceId,
                    null,
                    "Characteristic not found."
            );

            return false;
        }

        if (!beginOperation(
                deviceId,
                "read"
        )) {

            return false;
        }

        try {

            boolean started =
                    gatt.readCharacteristic(
                            characteristic
                    );

            if (!started) {

                clearPending(
                        deviceId,
                        "read"
                );

                dispatchReadError(
                        deviceId,
                        characteristic,
                        "Unable to start characteristic read."
                );
            }

            return started;

        } catch (SecurityException e) {

            clearPending(
                    deviceId,
                    "read"
            );

            dispatchReadError(
                    deviceId,
                    characteristic,
                    "BLE permission denied."
            );

            return false;

        } catch (Exception e) {

            clearPending(
                    deviceId,
                    "read"
            );

            dispatchReadError(
                    deviceId,
                    characteristic,
                    safeMessage(e)
            );

            return false;
        }
    }

    // ---------------------------------------------------------------------
    // Write with response
    // ---------------------------------------------------------------------

    public boolean write(
            final String deviceId,
            final String serviceUuid,
            final String characteristicUuid,
            final byte[] data
    ) {

        return writeInternal(
                deviceId,
                serviceUuid,
                characteristicUuid,
                data,
                false
        );
    }

    // ---------------------------------------------------------------------
    // Write without response
    // ---------------------------------------------------------------------

    public boolean writeWithoutResponse(
            final String deviceId,
            final String serviceUuid,
            final String characteristicUuid,
            final byte[] data
    ) {

        return writeInternal(
                deviceId,
                serviceUuid,
                characteristicUuid,
                data,
                true
        );
    }

    private boolean writeInternal(
            final String deviceId,
            final String serviceUuid,
            final String characteristicUuid,
            final byte[] data,
            final boolean withoutResponse
    ) {

        BluetoothGatt gatt =
                getConnection(deviceId);

        if (gatt == null) {
            return false;
        }

        if (data == null) {

            dispatchWriteError(
                    deviceId,
                    null,
                    "Data is required."
            );

            return false;
        }

        BluetoothGattCharacteristic characteristic =
                findCharacteristic(
                        deviceId,
                        serviceUuid,
                        characteristicUuid
                );

        if (characteristic == null) {

            dispatchWriteError(
                    deviceId,
                    null,
                    "Characteristic not found."
            );

            return false;
        }

        int properties =
                characteristic.getProperties();

        if (withoutResponse) {

            if ((properties &
                    BluetoothGattCharacteristic
                            .PROPERTY_WRITE_NO_RESPONSE)
                    == 0) {

                dispatchWriteError(
                        deviceId,
                        characteristic,
                        "Characteristic does not support "
                                + "write without response."
                );

                return false;
            }

            characteristic.setWriteType(
                    BluetoothGattCharacteristic
                            .WRITE_TYPE_NO_RESPONSE
            );

        } else {

            if ((properties &
                    BluetoothGattCharacteristic
                            .PROPERTY_WRITE)
                    == 0) {

                dispatchWriteError(
                        deviceId,
                        characteristic,
                        "Characteristic does not support write."
                );

                return false;
            }

            characteristic.setWriteType(
                    BluetoothGattCharacteristic
                            .WRITE_TYPE_DEFAULT
            );
        }

        if (!beginOperation(
                deviceId,
                "write"
        )) {

            return false;
        }

        try {

            if (Build.VERSION.SDK_INT >=
                    Build.VERSION_CODES.TIRAMISU) {

                int result =
                        gatt.writeCharacteristic(
                                characteristic,
                                data,
                                characteristic
                                        .getWriteType()
                        );

                if (result !=
                        BluetoothGatt.GATT_SUCCESS) {

                    clearPending(
                            deviceId,
                            "write"
                    );

                    dispatchWriteError(
                            deviceId,
                            characteristic,
                            "Unable to start characteristic write. "
                                    + "status="
                                    + result
                    );

                    return false;
                }

            } else {

                characteristic.setValue(data);

                boolean started =
                        gatt.writeCharacteristic(
                                characteristic
                        );

                if (!started) {

                    clearPending(
                            deviceId,
                            "write"
                    );

                    dispatchWriteError(
                            deviceId,
                            characteristic,
                            "Unable to start characteristic write."
                    );

                    return false;
                }
            }

            /*
             * WRITE_TYPE_NO_RESPONSE does not provide the same
             * acknowledgement callback as a normal write.
             *
             * We therefore report successful submission to the
             * Android Bluetooth stack immediately.
             */
            if (withoutResponse) {

                clearPending(
                        deviceId,
                        "write"
                );

                dispatchCharacteristicWritten(
                        deviceId,
                        characteristic,
                        true
                );
            }

            return true;

        } catch (SecurityException e) {

            clearPending(
                    deviceId,
                    "write"
            );

            dispatchWriteError(
                    deviceId,
                    characteristic,
                    "BLE permission denied."
            );

            return false;

        } catch (Exception e) {

            clearPending(
                    deviceId,
                    "write"
            );

            dispatchWriteError(
                    deviceId,
                    characteristic,
                    safeMessage(e)
            );

            return false;
        }
    }

    // ---------------------------------------------------------------------
    // Notifications / indications
    // ---------------------------------------------------------------------

    public boolean subscribe(
            final String deviceId,
            final String serviceUuid,
            final String characteristicUuid
    ) {

        BluetoothGatt gatt =
                getConnection(deviceId);

        if (gatt == null) {
            return false;
        }

        BluetoothGattCharacteristic characteristic =
                findCharacteristic(
                        deviceId,
                        serviceUuid,
                        characteristicUuid
                );

        if (characteristic == null) {

            dispatchNotificationError(
                    deviceId,
                    (BluetoothGattCharacteristic) null,
                    "Characteristic not found."
            );

            return false;
        }

        int properties =
                characteristic.getProperties();

        boolean supportsNotify =
                (properties &
                        BluetoothGattCharacteristic
                                .PROPERTY_NOTIFY) != 0;

        boolean supportsIndicate =
                (properties &
                        BluetoothGattCharacteristic
                                .PROPERTY_INDICATE) != 0;

        if (!supportsNotify
                && !supportsIndicate) {

            dispatchNotificationError(
                    deviceId,
                    characteristic,
                    "Characteristic does not support "
                            + "notifications or indications."
            );

            return false;
        }

        BluetoothGattDescriptor descriptor =
                characteristic.getDescriptor(
                        CCCD_UUID
                );

        if (descriptor == null) {

            dispatchNotificationError(
                    deviceId,
                    characteristic,
                    "CCCD descriptor not found."
            );

            return false;
        }

        if (!beginOperation(
                deviceId,
                "subscribe"
        )) {

            return false;
        }

        try {

            boolean localResult =
                    gatt.setCharacteristicNotification(
                            characteristic,
                            true
                    );

            if (!localResult) {

                clearPending(
                        deviceId,
                        "subscribe"
                );

                dispatchNotificationError(
                        deviceId,
                        characteristic,
                        "Unable to enable local "
                                + "characteristic notification."
                );

                return false;
            }

            byte[] value;

            if (supportsNotify) {

                value =
                        BluetoothGattDescriptor
                                .ENABLE_NOTIFICATION_VALUE;

            } else {

                value =
                        BluetoothGattDescriptor
                                .ENABLE_INDICATION_VALUE;
            }

            descriptor.setValue(value);

            boolean started =
                    gatt.writeDescriptor(
                            descriptor
                    );

            if (!started) {

                clearPending(
                        deviceId,
                        "subscribe"
                );

                dispatchNotificationError(
                        deviceId,
                        characteristic,
                        "Unable to write CCCD."
                );

                return false;
            }

            return true;

        } catch (SecurityException e) {

            clearPending(
                    deviceId,
                    "subscribe"
            );

            dispatchNotificationError(
                    deviceId,
                    characteristic,
                    "BLE permission denied."
            );

            return false;

        } catch (Exception e) {

            clearPending(
                    deviceId,
                    "subscribe"
            );

            dispatchNotificationError(
                    deviceId,
                    characteristic,
                    safeMessage(e)
            );

            return false;
        }
    }

    public boolean unsubscribe(
            final String deviceId,
            final String serviceUuid,
            final String characteristicUuid
    ) {

        BluetoothGatt gatt =
                getConnection(deviceId);

        if (gatt == null) {
            return false;
        }

        BluetoothGattCharacteristic characteristic =
                findCharacteristic(
                        deviceId,
                        serviceUuid,
                        characteristicUuid
                );

        if (characteristic == null) {

            dispatchNotificationError(
                    deviceId,
                    (BluetoothGattCharacteristic) null,
                    "Characteristic not found."
            );

            return false;
        }

        BluetoothGattDescriptor descriptor =
                characteristic.getDescriptor(
                        CCCD_UUID
                );

        if (descriptor == null) {

            dispatchNotificationError(
                    deviceId,
                    characteristic,
                    "CCCD descriptor not found."
            );

            return false;
        }

        if (!beginOperation(
                deviceId,
                "unsubscribe"
        )) {

            return false;
        }

        try {

            boolean localResult =
                    gatt.setCharacteristicNotification(
                            characteristic,
                            false
                    );

            if (!localResult) {

                clearPending(
                        deviceId,
                        "unsubscribe"
                );

                dispatchNotificationError(
                        deviceId,
                        characteristic,
                        "Unable to disable local "
                                + "characteristic notification."
                );

                return false;
            }

            descriptor.setValue(
                    BluetoothGattDescriptor
                            .DISABLE_NOTIFICATION_VALUE
            );

            boolean started =
                    gatt.writeDescriptor(
                            descriptor
                    );

            if (!started) {

                clearPending(
                        deviceId,
                        "unsubscribe"
                );

                dispatchNotificationError(
                        deviceId,
                        characteristic,
                        "Unable to write CCCD."
                );

                return false;
            }

            return true;

        } catch (SecurityException e) {

            clearPending(
                    deviceId,
                    "unsubscribe"
            );

            dispatchNotificationError(
                    deviceId,
                    characteristic,
                    "BLE permission denied."
            );

            return false;

        } catch (Exception e) {

            clearPending(
                    deviceId,
                    "unsubscribe"
            );

            dispatchNotificationError(
                    deviceId,
                    characteristic,
                    safeMessage(e)
            );

            return false;
        }
    }

    // ---------------------------------------------------------------------
    // GATT lookup
    // ---------------------------------------------------------------------

    private BluetoothGatt getConnection(
            String deviceId
    ) {

        if (deviceId == null) {

            dispatchError(
                    "Device ID is required."
            );

            return null;
        }

        BluetoothGatt gatt =
                connections.get(deviceId);

        if (gatt == null) {

            dispatchError(
                    "Device is not connected: "
                            + deviceId
            );

            return null;
        }

        return gatt;
    }

    private BluetoothGattService findService(
            String deviceId,
            String serviceUuid
    ) {

        if (serviceUuid == null) {
            return null;
        }

        List<BluetoothGattService> services =
                servicesCache.get(deviceId);

        if (services == null) {

            BluetoothGatt gatt =
                    connections.get(deviceId);

            if (gatt != null) {
                services = gatt.getServices();
            }
        }

        if (services == null) {
            return null;
        }

        for (BluetoothGattService service :
                services) {

            if (service.getUuid()
                    .toString()
                    .equalsIgnoreCase(serviceUuid)) {

                return service;
            }
        }

        return null;
    }

    private BluetoothGattCharacteristic
    findCharacteristic(
            String deviceId,
            String serviceUuid,
            String characteristicUuid
    ) {

        BluetoothGattService service =
                findService(
                        deviceId,
                        serviceUuid
                );

        if (service == null) {
            return null;
        }

        if (characteristicUuid == null) {
            return null;
        }

        for (BluetoothGattCharacteristic characteristic :
                service.getCharacteristics()) {

            if (characteristic.getUuid()
                    .toString()
                    .equalsIgnoreCase(
                            characteristicUuid
                    )) {

                return characteristic;
            }
        }

        return null;
    }

    // ---------------------------------------------------------------------
    // Operation serialization
    // ---------------------------------------------------------------------

    private boolean beginOperation(
            String deviceId,
            String operation
    ) {

        synchronized (pendingOperations) {

            String existing =
                    pendingOperations.get(
                            deviceId
                    );

            if (existing != null) {

                dispatchError(
                        "BLE operation already pending: "
                                + existing
                );

                return false;
            }

            pendingOperations.put(
                    deviceId,
                    operation
            );

            return true;
        }
    }

    private void clearPending(
            String deviceId,
            String expectedOperation
    ) {

        synchronized (pendingOperations) {

            String current =
                    pendingOperations.get(
                            deviceId
                    );

            if (expectedOperation == null
                    || expectedOperation.equals(
                            current
                    )) {

                pendingOperations.remove(
                        deviceId
                );
            }
        }
    }

    // ---------------------------------------------------------------------
    // Notification state
    // ---------------------------------------------------------------------

    private void addNotificationState(
            String deviceId,
            BluetoothGattCharacteristic characteristic
    ) {

        synchronized (
                notificationCharacteristics
        ) {

            Set<String> set =
                    notificationCharacteristics.get(
                            deviceId
                    );

            if (set == null) {

                set = new HashSet<>();

                notificationCharacteristics.put(
                        deviceId,
                        set
                );
            }

            set.add(
                    characteristic.getUuid()
                            .toString()
                            .toLowerCase()
            );
        }
    }

    private void removeNotificationState(
            String deviceId,
            BluetoothGattCharacteristic characteristic
    ) {

        synchronized (
                notificationCharacteristics
        ) {

            Set<String> set =
                    notificationCharacteristics.get(
                            deviceId
                    );

            if (set == null) {
                return;
            }

            set.remove(
                    characteristic.getUuid()
                            .toString()
                            .toLowerCase()
            );

            if (set.isEmpty()) {

                notificationCharacteristics.remove(
                        deviceId
                );
            }
        }
    }

    // ---------------------------------------------------------------------
    // Event dispatch: scan
    // ---------------------------------------------------------------------

    private void dispatchDeviceFound(
            final String id,
            final String deviceName,
            final int rssi
    ) {

        if (runtimeDispatcher == null) {
            return;
        }

        runtimeDispatcher.send(
                new CoronaRuntimeTask() {

                    @Override
                    public void executeUsing(
                            CoronaRuntime runtime
                    ) {

                        LuaState L =
                                runtime.getLuaState();

                        CoronaLua.newEvent(
                                L,
                                "deviceFound"
                        );

                        L.pushString(id);
                        L.setField(
                                -2,
                                "id"
                        );

                        if (deviceName != null) {

                            L.pushString(
                                    deviceName
                            );

                            L.setField(
                                    -2,
                                    "deviceName"
                            );
                        }

                        L.pushInteger(rssi);

                        L.setField(
                                -2,
                                "rssi"
                        );

                        dispatchLuaEvent(
                                L
                        );
                    }
                }
        );
    }

    // ---------------------------------------------------------------------
    // Event dispatch: connection
    // ---------------------------------------------------------------------

    private void dispatchConnected(
            final String deviceId
    ) {

        dispatchSimpleDeviceEvent(
                "connected",
                deviceId
        );
    }

    private void dispatchDisconnected(
            final String deviceId
    ) {

        dispatchSimpleDeviceEvent(
                "disconnected",
                deviceId
        );
    }

    private void dispatchConnectionError(
            final String deviceId,
            final String message
    ) {

        if (runtimeDispatcher == null) {
            return;
        }

        runtimeDispatcher.send(
                new CoronaRuntimeTask() {

                    @Override
                    public void executeUsing(
                            CoronaRuntime runtime
                    ) {

                        LuaState L =
                                runtime.getLuaState();

                        CoronaLua.newEvent(
                                L,
                                "connectionError"
                        );

                        if (deviceId != null) {

                            L.pushString(
                                    deviceId
                            );

                            L.setField(
                                    -2,
                                    "deviceId"
                            );

                            L.pushString(
                                    deviceId
                            );

                            L.setField(
                                    -2,
                                    "id"
                            );
                        }

                        L.pushString(
                                message != null
                                        ? message
                                        : "Unknown connection error."
                        );

                        L.setField(
                                -2,
                                "message"
                        );

                        dispatchLuaEvent(
                                L
                        );
                    }
                }
        );
    }

    // ---------------------------------------------------------------------
    // Event dispatch: services
    // ---------------------------------------------------------------------

    private void dispatchServicesDiscovered(
                final String deviceId,
                final List<BluetoothGattService> services
        ) {

        if (runtimeDispatcher == null) {
                return;
        }

        /*
        * Copy the list because Android owns the original collection.
        */
        final List<BluetoothGattService> safeServices =
                services == null
                        ? new ArrayList<BluetoothGattService>()
                        : new ArrayList<>(services);

        runtimeDispatcher.send(
                new CoronaRuntimeTask() {

                        @Override
                        public void executeUsing(
                                CoronaRuntime runtime
                        ) {

                        LuaState L =
                                runtime.getLuaState();

                        CoronaLua.newEvent(
                                L,
                                "servicesDiscovered"
                        );

                        /*
                        * Device ID
                        */
                        L.pushString(deviceId);
                        L.setField(
                                -2,
                                "deviceId"
                        );

                        L.pushString(deviceId);
                        L.setField(
                                -2,
                                "id"
                        );

                        /*
                        * services = {
                        *
                        *     {
                        *         uuid = "...",
                        *         type = "primary",
                        *         characteristicCount = 2,
                        *
                        *         characteristics = {
                        *
                        *             {
                        *                 uuid = "...",
                        *                 properties = "READ, NOTIFY",
                        *                 propertiesValue = 18
                        *             }
                        *
                        *         }
                        *     }
                        *
                        * }
                        */
                        L.newTable();

                        int servicesTable =
                                L.getTop();

                        int serviceIndex = 1;

                        for (BluetoothGattService service :
                                safeServices) {

                                if (service == null) {
                                continue;
                                }

                                /*
                                * Service table
                                */
                                L.newTable();

                                int serviceTable =
                                        L.getTop();

                                /*
                                * Service UUID
                                */
                                L.pushString(
                                        service.getUuid()
                                                .toString()
                                );

                                L.setField(
                                        serviceTable,
                                        "uuid"
                                );

                                /*
                                * Service type
                                */
                                L.pushString(
                                        serviceTypeName(
                                                service.getType()
                                        )
                                );

                                L.setField(
                                        serviceTable,
                                        "type"
                                );

                                /*
                                * Get characteristics
                                */
                                List<BluetoothGattCharacteristic>
                                        characteristics =
                                        service.getCharacteristics();

                                if (characteristics == null) {

                                characteristics =
                                        new ArrayList<
                                                BluetoothGattCharacteristic
                                        >();
                                }

                                /*
                                * Characteristic count
                                */
                                L.pushInteger(
                                        characteristics.size()
                                );

                                L.setField(
                                        serviceTable,
                                        "characteristicCount"
                                );

                                /*
                                * characteristics = {}
                                */
                                L.newTable();

                                int characteristicsTable =
                                        L.getTop();

                                int characteristicIndex = 1;

                                for (
                                        BluetoothGattCharacteristic characteristic
                                        : characteristics
                                ) {

                                if (characteristic == null) {
                                        continue;
                                }

                                /*
                                * Characteristic table
                                */
                                L.newTable();

                                int characteristicTable =
                                        L.getTop();

                                /*
                                * UUID
                                */
                                L.pushString(
                                        characteristic
                                                .getUuid()
                                                .toString()
                                );

                                L.setField(
                                        characteristicTable,
                                        "uuid"
                                );

                                /*
                                * Numeric Android property flags
                                */
                                int properties =
                                        characteristic
                                                .getProperties();

                                L.pushInteger(
                                        properties
                                );

                                L.setField(
                                        characteristicTable,
                                        "propertiesValue"
                                );

                                /*
                                * Human-readable properties
                                */
                                L.pushString(
                                        characteristicPropertiesName(
                                                properties
                                        )
                                );

                                L.setField(
                                        characteristicTable,
                                        "properties"
                                );

                                /*
                                * Individual boolean capabilities.
                                * These are useful from Lua because
                                * the numeric Android bitmask isn't
                                * particularly convenient there.
                                */

                                L.pushBoolean(
                                        (properties &
                                                BluetoothGattCharacteristic
                                                        .PROPERTY_READ)
                                                != 0
                                );

                                L.setField(
                                        characteristicTable,
                                        "canRead"
                                );

                                L.pushBoolean(
                                        (properties &
                                                BluetoothGattCharacteristic
                                                        .PROPERTY_WRITE)
                                                != 0
                                );

                                L.setField(
                                        characteristicTable,
                                        "canWrite"
                                );

                                L.pushBoolean(
                                        (properties &
                                                BluetoothGattCharacteristic
                                                        .PROPERTY_WRITE_NO_RESPONSE)
                                                != 0
                                );

                                L.setField(
                                        characteristicTable,
                                        "canWriteWithoutResponse"
                                );

                                L.pushBoolean(
                                        (properties &
                                                BluetoothGattCharacteristic
                                                        .PROPERTY_NOTIFY)
                                                != 0
                                );

                                L.setField(
                                        characteristicTable,
                                        "canNotify"
                                );

                                L.pushBoolean(
                                        (properties &
                                                BluetoothGattCharacteristic
                                                        .PROPERTY_INDICATE)
                                                != 0
                                );

                                L.setField(
                                        characteristicTable,
                                        "canIndicate"
                                );

                                /*
                                * Add characteristic to:
                                *
                                * characteristics[index]
                                */
                                L.rawSet(
                                        characteristicsTable,
                                        characteristicIndex++
                                );
                                }

                                /*
                                * service.characteristics =
                                * characteristicsTable
                                */
                                L.setField(
                                        serviceTable,
                                        "characteristics"
                                );

                                /*
                                * Add service to:
                                *
                                * services[index]
                                */
                                L.rawSet(
                                        servicesTable,
                                        serviceIndex++
                                );
                        }

                        /*
                        * event.services = servicesTable
                        */
                        L.setField(
                                -2,
                                "services"
                        );

                        /*
                        * event.count
                        */
                        L.pushInteger(
                                safeServices.size()
                        );

                        L.setField(
                                -2,
                                "count"
                        );

                        dispatchLuaEvent(
                                L
                        );
                        }
                }
        );
        }

    // ---------------------------------------------------------------------
    // Event dispatch: read
    // ---------------------------------------------------------------------

    private void dispatchCharacteristicRead(
            final String deviceId,
            final BluetoothGattCharacteristic
                    characteristic,
            final byte[] value
    ) {

        if (runtimeDispatcher == null) {
            return;
        }

        final byte[] safeValue =
                value != null
                        ? value.clone()
                        : new byte[0];

        final String serviceUuid =
                getServiceUuid(
                        characteristic
                );

        final String characteristicUuid =
                characteristic != null
                        ? characteristic.getUuid()
                                .toString()
                        : null;

        runtimeDispatcher.send(
                new CoronaRuntimeTask() {

                    @Override
                    public void executeUsing(
                            CoronaRuntime runtime
                    ) {

                        LuaState L =
                                runtime.getLuaState();

                        CoronaLua.newEvent(
                                L,
                                "characteristicRead"
                        );

                        pushCommonCharacteristicFields(
                                L,
                                deviceId,
                                serviceUuid,
                                characteristicUuid
                        );

                        L.pushString(
                                safeValue
                        );

                        L.setField(
                                -2,
                                "data"
                        );

                        L.pushInteger(
                                safeValue.length
                        );

                        L.setField(
                                -2,
                                "length"
                        );

                        dispatchLuaEvent(
                                L
                        );
                    }
                }
        );
    }

    // ---------------------------------------------------------------------
    // Event dispatch: write
    // ---------------------------------------------------------------------

    private void dispatchCharacteristicWritten(
            final String deviceId,
            final BluetoothGattCharacteristic
                    characteristic,
            final boolean withoutResponse
    ) {

        if (runtimeDispatcher == null) {
            return;
        }

        final String serviceUuid =
                getServiceUuid(
                        characteristic
                );

        final String characteristicUuid =
                characteristic != null
                        ? characteristic.getUuid()
                                .toString()
                        : null;

        runtimeDispatcher.send(
                new CoronaRuntimeTask() {

                    @Override
                    public void executeUsing(
                            CoronaRuntime runtime
                    ) {

                        LuaState L =
                                runtime.getLuaState();

                        CoronaLua.newEvent(
                                L,
                                "characteristicWritten"
                        );

                        pushCommonCharacteristicFields(
                                L,
                                deviceId,
                                serviceUuid,
                                characteristicUuid
                        );

                        L.pushBoolean(
                                withoutResponse
                        );

                        L.setField(
                                -2,
                                "withoutResponse"
                        );

                        dispatchLuaEvent(
                                L
                        );
                    }
                }
        );
    }

    // ---------------------------------------------------------------------
    // Event dispatch: notification
    // ---------------------------------------------------------------------

    private void dispatchCharacteristicChanged(
            final String deviceId,
            final BluetoothGattCharacteristic
                    characteristic,
            final byte[] value
    ) {

        if (runtimeDispatcher == null) {
            return;
        }

        final byte[] safeValue =
                value != null
                        ? value.clone()
                        : new byte[0];

        final String serviceUuid =
                getServiceUuid(
                        characteristic
                );

        final String characteristicUuid =
                characteristic != null
                        ? characteristic.getUuid()
                                .toString()
                        : null;

        runtimeDispatcher.send(
                new CoronaRuntimeTask() {

                    @Override
                    public void executeUsing(
                            CoronaRuntime runtime
                    ) {

                        LuaState L =
                                runtime.getLuaState();

                        CoronaLua.newEvent(
                                L,
                                "characteristicChanged"
                        );

                        pushCommonCharacteristicFields(
                                L,
                                deviceId,
                                serviceUuid,
                                characteristicUuid
                        );

                        L.pushString(
                                safeValue
                        );

                        L.setField(
                                -2,
                                "data"
                        );

                        L.pushInteger(
                                safeValue.length
                        );

                        L.setField(
                                -2,
                                "length"
                        );

                        dispatchLuaEvent(
                                L
                        );
                    }
                }
        );
    }

    private void dispatchNotificationStateChanged(
            final String deviceId,
            final BluetoothGattCharacteristic
                    characteristic,
            final boolean enabled
    ) {

        if (runtimeDispatcher == null) {
            return;
        }

        final String serviceUuid =
                getServiceUuid(
                        characteristic
                );

        final String characteristicUuid =
                characteristic != null
                        ? characteristic.getUuid()
                                .toString()
                        : null;

        runtimeDispatcher.send(
                new CoronaRuntimeTask() {

                    @Override
                    public void executeUsing(
                            CoronaRuntime runtime
                    ) {

                        LuaState L =
                                runtime.getLuaState();

                        CoronaLua.newEvent(
                                L,
                                "notificationStateChanged"
                        );

                        pushCommonCharacteristicFields(
                                L,
                                deviceId,
                                serviceUuid,
                                characteristicUuid
                        );

                        L.pushBoolean(enabled);

                        L.setField(
                                -2,
                                "enabled"
                        );

                        dispatchLuaEvent(
                                L
                        );
                    }
                }
        );
    }

    // ---------------------------------------------------------------------
    // Event dispatch: errors
    // ---------------------------------------------------------------------

    private void dispatchServiceError(
            final String deviceId,
            final String message
    ) {

        dispatchOperationError(
                "serviceError",
                deviceId,
                null,
                null,
                message
        );
    }

    private void dispatchReadError(
            final String deviceId,
            final BluetoothGattCharacteristic
                    characteristic,
            final String message
    ) {

        dispatchOperationError(
                "readError",
                deviceId,
                getServiceUuid(characteristic),
                characteristic != null
                        ? characteristic.getUuid()
                                .toString()
                        : null,
                message
        );
    }

    private void dispatchWriteError(
            final String deviceId,
            final BluetoothGattCharacteristic
                    characteristic,
            final String message
    ) {

        dispatchOperationError(
                "writeError",
                deviceId,
                getServiceUuid(characteristic),
                characteristic != null
                        ? characteristic.getUuid()
                                .toString()
                        : null,
                message
        );
    }

    private void dispatchNotificationError(
            final String deviceId,
            final BluetoothGattDescriptor
                    descriptor,
            final String message
    ) {

        BluetoothGattCharacteristic characteristic =
                descriptor != null
                        ? descriptor.getCharacteristic()
                        : null;

        dispatchNotificationError(
                deviceId,
                characteristic,
                message
        );
    }

    private void dispatchNotificationError(
            final String deviceId,
            final BluetoothGattCharacteristic
                    characteristic,
            final String message
    ) {

        dispatchOperationError(
                "notificationError",
                deviceId,
                getServiceUuid(characteristic),
                characteristic != null
                        ? characteristic.getUuid()
                                .toString()
                        : null,
                message
        );
    }

    private void dispatchOperationError(
            final String eventName,
            final String deviceId,
            final String serviceUuid,
            final String characteristicUuid,
            final String message
    ) {

        if (runtimeDispatcher == null) {
            return;
        }

        runtimeDispatcher.send(
                new CoronaRuntimeTask() {

                    @Override
                    public void executeUsing(
                            CoronaRuntime runtime
                    ) {

                        LuaState L =
                                runtime.getLuaState();

                        CoronaLua.newEvent(
                                L,
                                eventName
                        );

                        if (deviceId != null) {

                            L.pushString(deviceId);
                            L.setField(
                                    -2,
                                    "deviceId"
                            );

                            L.pushString(deviceId);
                            L.setField(
                                    -2,
                                    "id"
                            );
                        }

                        if (serviceUuid != null) {

                            L.pushString(
                                    serviceUuid
                            );

                            L.setField(
                                    -2,
                                    "serviceUuid"
                            );
                        }

                        if (characteristicUuid != null) {

                            L.pushString(
                                    characteristicUuid
                            );

                            L.setField(
                                    -2,
                                    "characteristicUuid"
                            );
                        }

                        L.pushString(
                                message != null
                                        ? message
                                        : "Unknown BLE error."
                        );

                        L.setField(
                                -2,
                                "message"
                        );

                        dispatchLuaEvent(
                                L
                        );
                    }
                }
        );
    }

    private void dispatchScanError(
            final int errorCode
    ) {

        if (runtimeDispatcher == null) {
            return;
        }

        runtimeDispatcher.send(
                new CoronaRuntimeTask() {

                    @Override
                    public void executeUsing(
                            CoronaRuntime runtime
                    ) {

                        LuaState L =
                                runtime.getLuaState();

                        CoronaLua.newEvent(
                                L,
                                "scanError"
                        );

                        L.pushInteger(
                                errorCode
                        );

                        L.setField(
                                -2,
                                "errorCode"
                        );

                        dispatchLuaEvent(
                                L
                        );
                    }
                }
        );
    }

    private void dispatchError(
            final String message
    ) {

        if (runtimeDispatcher == null) {
            return;
        }

        runtimeDispatcher.send(
                new CoronaRuntimeTask() {

                    @Override
                    public void executeUsing(
                            CoronaRuntime runtime
                    ) {

                        LuaState L =
                                runtime.getLuaState();

                        CoronaLua.newEvent(
                                L,
                                "error"
                        );

                        L.pushString(
                                message != null
                                        ? message
                                        : "Unknown BLE error."
                        );

                        L.setField(
                                -2,
                                "message"
                        );

                        dispatchLuaEvent(
                                L
                        );
                    }
                }
        );
    }

    // ---------------------------------------------------------------------
    // Lua helpers
    // ---------------------------------------------------------------------

    private void dispatchSimpleDeviceEvent(
            final String eventName,
            final String deviceId
    ) {

        if (runtimeDispatcher == null) {
            return;
        }

        runtimeDispatcher.send(
                new CoronaRuntimeTask() {

                    @Override
                    public void executeUsing(
                            CoronaRuntime runtime
                    ) {

                        LuaState L =
                                runtime.getLuaState();

                        CoronaLua.newEvent(
                                L,
                                eventName
                        );

                        L.pushString(
                                deviceId
                        );

                        L.setField(
                                -2,
                                "deviceId"
                        );

                        L.pushString(
                                deviceId
                        );

                        L.setField(
                                -2,
                                "id"
                        );

                        dispatchLuaEvent(
                                L
                        );
                    }
                }
        );
    }

    private void pushCommonCharacteristicFields(
            LuaState L,
            String deviceId,
            String serviceUuid,
            String characteristicUuid
    ) {

        if (deviceId != null) {

            L.pushString(deviceId);
            L.setField(
                    -2,
                    "deviceId"
            );

            L.pushString(deviceId);
            L.setField(
                    -2,
                    "id"
            );
        }

        if (serviceUuid != null) {

            L.pushString(serviceUuid);
            L.setField(
                    -2,
                    "serviceUuid"
            );
        }

        if (characteristicUuid != null) {

            L.pushString(characteristicUuid);
            L.setField(
                    -2,
                    "characteristicUuid"
            );
        }
    }

    private void dispatchLuaEvent(
            LuaState L
    ) {

        try {

            CoronaLua.dispatchEvent(
                    L,
                    listenerReference,
                    0
            );

        } catch (Exception e) {

            e.printStackTrace();
        }
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    private String getServiceUuid(
            BluetoothGattCharacteristic characteristic
    ) {

        if (characteristic == null) {
            return null;
        }

        BluetoothGattService service =
                characteristic.getService();

        if (service == null) {
            return null;
        }

        return service.getUuid().toString();
    }

    private String serviceTypeName(
            int type
    ) {

        if (type ==
                BluetoothGattService.SERVICE_TYPE_PRIMARY) {

            return "primary";

        } else if (
                type ==
                        BluetoothGattService
                                .SERVICE_TYPE_SECONDARY
        ) {

            return "secondary";
        }

        return "unknown";
    }

    private String characteristicPropertiesName(
                int properties
        ) {

        List<String> result =
                new ArrayList<>();

        if ((properties &
                BluetoothGattCharacteristic.PROPERTY_BROADCAST) != 0) {

                result.add("BROADCAST");
        }

        if ((properties &
                BluetoothGattCharacteristic.PROPERTY_READ) != 0) {

                result.add("READ");
        }

        if ((properties &
                BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE) != 0) {

                result.add("WRITE_NO_RESPONSE");
        }

        if ((properties &
                BluetoothGattCharacteristic.PROPERTY_WRITE) != 0) {

                result.add("WRITE");
        }

        if ((properties &
                BluetoothGattCharacteristic.PROPERTY_NOTIFY) != 0) {

                result.add("NOTIFY");
        }

        if ((properties &
                BluetoothGattCharacteristic.PROPERTY_INDICATE) != 0) {

                result.add("INDICATE");
        }

        if ((properties &
                BluetoothGattCharacteristic.PROPERTY_SIGNED_WRITE) != 0) {

                result.add("SIGNED_WRITE");
        }

        if (result.isEmpty()) {
                return "NONE";
        }

        return android.text.TextUtils.join(
                ", ",
                result
        );
        }

    private String safeMessage(
            Exception e
    ) {

        if (e == null) {
            return "Unknown error.";
        }

        String message =
                e.getMessage();

        return message != null
                ? message
                : e.getClass()
                        .getSimpleName();
    }

    // ---------------------------------------------------------------------
    // Cleanup
    // ---------------------------------------------------------------------

    public void destroy() {

        stopScan();

        for (BluetoothGatt gatt :
                connections.values()) {

            if (gatt == null) {
                continue;
            }

            try {
                gatt.disconnect();
            } catch (Exception ignored) {
            }

            try {
                gatt.close();
            } catch (Exception ignored) {
            }
        }

        connections.clear();
        servicesCache.clear();
        pendingOperations.clear();
        notificationCharacteristics.clear();

        synchronized (discoveredDevices) {
            discoveredDevices.clear();
        }

        runtimeDispatcher = null;
        listenerReference = CoronaLua.REFNIL;
    }
}