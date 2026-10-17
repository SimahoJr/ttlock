package plugin.ble;

import com.ansca.corona.CoronaEnvironment;
import com.ansca.corona.CoronaLua;
import com.ansca.corona.CoronaRuntime;
import com.ansca.corona.CoronaRuntimeListener;

import com.naef.jnlua.JavaFunction;
import com.naef.jnlua.LuaState;
import com.naef.jnlua.NamedJavaFunction;

import java.util.List;

import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattService;

@SuppressWarnings({
        "unused",
        "WeakerAccess"
})
public class LuaLoader
        implements JavaFunction, CoronaRuntimeListener {

    private static final String EVENT_NAME =
            "ble";

    private int listenerReference =
            CoronaLua.REFNIL;

    private final BleManager bleManager;

    public LuaLoader() {

        bleManager =
                new BleManager();

        CoronaEnvironment.addRuntimeListener(
                this
        );
    }

    @Override
    public int invoke(
            LuaState L
    ) {

        NamedJavaFunction[] luaFunctions =
                new NamedJavaFunction[] {

                        // State
                        new InitWrapper(),
                        new IsSupportedWrapper(),
                        new IsEnabledWrapper(),
                        new HasPermissionWrapper(),
                        new RequestPermissionWrapper(),

                        // Scan
                        new StartScanWrapper(),
                        new StopScanWrapper(),

                        // Connection
                        new ConnectWrapper(),
                        new DisconnectWrapper(),

                        // GATT
                        new DiscoverServicesWrapper(),
                        new GetServicesWrapper(),
                        new GetCharacteristicsWrapper(),

                        // Data
                        new ReadWrapper(),
                        new WriteWrapper(),
                        new WriteWithoutResponseWrapper(),

                        // Notifications
                        new SubscribeWrapper(),
                        new UnsubscribeWrapper()
                };

        L.register(
                L.toString(1),
                luaFunctions
        );

        return 1;
    }

    // =====================================================================
    // init
    // =====================================================================

    private class InitWrapper
            implements NamedJavaFunction {

        @Override
        public String getName() {

            return "init";
        }

        @Override
        public int invoke(
                LuaState L
        ) {

            if (CoronaLua.isListener(
                    L,
                    1,
                    EVENT_NAME
            )) {

                if (listenerReference !=
                        CoronaLua.REFNIL) {

                    CoronaLua.deleteRef(
                            L,
                            listenerReference
                    );
                }

                listenerReference =
                        CoronaLua.newRef(
                                L,
                                1
                        );

                bleManager.initialize(
                        L,
                        listenerReference
                );
            }

            return 0;
        }
    }

    // =====================================================================
    // isSupported
    // =====================================================================

    private class IsSupportedWrapper
            implements NamedJavaFunction {

        @Override
        public String getName() {

            return "isSupported";
        }

        @Override
        public int invoke(
                LuaState L
        ) {

            L.pushBoolean(
                    bleManager.isSupported()
            );

            return 1;
        }
    }

    // =====================================================================
    // isEnabled
    // =====================================================================

    private class IsEnabledWrapper
            implements NamedJavaFunction {

        @Override
        public String getName() {

            return "isEnabled";
        }

        @Override
        public int invoke(
                LuaState L
        ) {

            L.pushBoolean(
                    bleManager.isEnabled()
            );

            return 1;
        }
    }

    // =====================================================================
    // hasPermission
    // =====================================================================

    private class HasPermissionWrapper
            implements NamedJavaFunction {

        @Override
        public String getName() {

            return "hasPermission";
        }

        @Override
        public int invoke(
                LuaState L
        ) {

            L.pushBoolean(
                    bleManager.hasPermission()
            );

            return 1;
        }
    }

    // =====================================================================
    // requestPermission
    // =====================================================================

    private class RequestPermissionWrapper
            implements NamedJavaFunction {

        @Override
        public String getName() {

            return "requestPermission";
        }

        @Override
        public int invoke(
                LuaState L
        ) {

            bleManager.requestPermission();

            return 0;
        }
    }

    // =====================================================================
    // startScan
    // =====================================================================

    private class StartScanWrapper
            implements NamedJavaFunction {

        @Override
        public String getName() {

            return "startScan";
        }

        @Override
        public int invoke(
                LuaState L
        ) {

            L.pushBoolean(
                    bleManager.startScan()
            );

            return 1;
        }
    }

    // =====================================================================
    // stopScan
    // =====================================================================

    private class StopScanWrapper
            implements NamedJavaFunction {

        @Override
        public String getName() {

            return "stopScan";
        }

        @Override
        public int invoke(
                LuaState L
        ) {

            bleManager.stopScan();

            return 0;
        }
    }

    // =====================================================================
    // connect
    // =====================================================================

    private class ConnectWrapper
            implements NamedJavaFunction {

        @Override
        public String getName() {

            return "connect";
        }

        @Override
        public int invoke(
                LuaState L
        ) {

            String deviceId =
                    L.toString(1);

            if (deviceId == null
                    || deviceId.length() == 0) {

                L.pushBoolean(false);

                return 1;
            }

            L.pushBoolean(
                    bleManager.connect(
                            deviceId
                    )
            );

            return 1;
        }
    }

    // =====================================================================
    // disconnect
    // =====================================================================

    private class DisconnectWrapper
            implements NamedJavaFunction {

        @Override
        public String getName() {

            return "disconnect";
        }

        @Override
        public int invoke(
                LuaState L
        ) {

            String deviceId =
                    L.toString(1);

            if (deviceId != null
                    && deviceId.length() > 0) {

                bleManager.disconnect(
                        deviceId
                );
            }

            return 0;
        }
    }

    // =====================================================================
    // discoverServices
    // =====================================================================

    private class DiscoverServicesWrapper
            implements NamedJavaFunction {

        @Override
        public String getName() {

            return "discoverServices";
        }

        @Override
        public int invoke(
                LuaState L
        ) {

            String deviceId =
                    L.toString(1);

            if (deviceId == null
                    || deviceId.length() == 0) {

                L.pushBoolean(false);

                return 1;
            }

            L.pushBoolean(
                    bleManager.discoverServices(
                            deviceId
                    )
            );

            return 1;
        }
    }

    // =====================================================================
    // getServices
    // =====================================================================

    private class GetServicesWrapper
            implements NamedJavaFunction {

        @Override
        public String getName() {

            return "getServices";
        }

        @Override
        public int invoke(
                LuaState L
        ) {

            String deviceId =
                    L.toString(1);

            List<BluetoothGattService> services =
                    bleManager.getServices(
                            deviceId
                    );

            if (services == null) {

                L.pushNil();

                return 1;
            }

            L.newTable();

            int tableIndex =
                    L.getTop();

            int index = 1;

            for (BluetoothGattService service :
                    services) {

                L.newTable();

                L.pushString(
                        service.getUuid()
                                .toString()
                );

                L.setField(
                        -2,
                        "uuid"
                );

                L.pushString(
                        service.getType()
                                ==
                                BluetoothGattService
                                        .SERVICE_TYPE_PRIMARY
                                ? "primary"
                                : "secondary"
                );

                L.setField(
                        -2,
                        "type"
                );

                L.pushInteger(
                        service
                                .getCharacteristics()
                                .size()
                );

                L.setField(
                        -2,
                        "characteristicCount"
                );

                L.rawSet(
                        tableIndex,
                        index++
                );
            }

            return 1;
        }
    }

    // =====================================================================
    // getCharacteristics
    // =====================================================================

    private class GetCharacteristicsWrapper
            implements NamedJavaFunction {

        @Override
        public String getName() {

            return "getCharacteristics";
        }

        @Override
        public int invoke(
                LuaState L
        ) {

            String deviceId =
                    L.toString(1);

            String serviceUuid =
                    L.toString(2);

            List<BluetoothGattCharacteristic>
                    characteristics =
                    bleManager
                            .getCharacteristics(
                                    deviceId,
                                    serviceUuid
                            );

            if (characteristics == null) {

                L.pushNil();

                return 1;
            }

            L.newTable();

            int tableIndex =
                    L.getTop();

            int index = 1;

            for (BluetoothGattCharacteristic
                    characteristic :
                    characteristics) {

                L.newTable();

                String uuid =
                        characteristic
                                .getUuid()
                                .toString();

                int properties =
                        characteristic
                                .getProperties();

                L.pushString(uuid);

                L.setField(
                        -2,
                        "uuid"
                );

                L.pushInteger(
                        properties
                );

                L.setField(
                        -2,
                        "properties"
                );

                L.pushBoolean(
                        (properties &
                                BluetoothGattCharacteristic
                                        .PROPERTY_READ)
                                != 0
                );

                L.setField(
                        -2,
                        "read"
                );

                L.pushBoolean(
                        (properties &
                                BluetoothGattCharacteristic
                                        .PROPERTY_WRITE)
                                != 0
                );

                L.setField(
                        -2,
                        "write"
                );

                L.pushBoolean(
                        (properties &
                                BluetoothGattCharacteristic
                                        .PROPERTY_WRITE_NO_RESPONSE)
                                != 0
                );

                L.setField(
                        -2,
                        "writeWithoutResponse"
                );

                L.pushBoolean(
                        (properties &
                                BluetoothGattCharacteristic
                                        .PROPERTY_NOTIFY)
                                != 0
                );

                L.setField(
                        -2,
                        "notify"
                );

                L.pushBoolean(
                        (properties &
                                BluetoothGattCharacteristic
                                        .PROPERTY_INDICATE)
                                != 0
                );

                L.setField(
                        -2,
                        "indicate"
                );

                L.rawSet(
                        tableIndex,
                        index++
                );
            }

            return 1;
        }
    }

    // =====================================================================
    // read
    // =====================================================================

    private class ReadWrapper
            implements NamedJavaFunction {

        @Override
        public String getName() {

            return "read";
        }

        @Override
        public int invoke(
                LuaState L
        ) {

            String deviceId =
                    L.toString(1);

            String serviceUuid =
                    L.toString(2);

            String characteristicUuid =
                    L.toString(3);

            if (deviceId == null
                    || serviceUuid == null
                    || characteristicUuid == null) {

                L.pushBoolean(false);

                return 1;
            }

            L.pushBoolean(
                    bleManager.read(
                            deviceId,
                            serviceUuid,
                            characteristicUuid
                    )
            );

            return 1;
        }
    }

    // =====================================================================
    // write
    // =====================================================================

    private class WriteWrapper
            implements NamedJavaFunction {

        @Override
        public String getName() {

            return "write";
        }

        @Override
        public int invoke(
                LuaState L
        ) {

            String deviceId =
                    L.toString(1);

            String serviceUuid =
                    L.toString(2);

            String characteristicUuid =
                    L.toString(3);

            if (deviceId == null
                    || serviceUuid == null
                    || characteristicUuid == null
                    || L.isNoneOrNil(4)) {

                L.pushBoolean(false);

                return 1;
            }

            byte[] data;

            try {

                data =
                        L.toByteArray(4);

            } catch (Exception e) {

                L.pushBoolean(false);

                return 1;
            }

            if (data == null) {

                L.pushBoolean(false);

                return 1;
            }

            L.pushBoolean(
                    bleManager.write(
                            deviceId,
                            serviceUuid,
                            characteristicUuid,
                            data
                    )
            );

            return 1;
        }
    }

    // =====================================================================
    // writeWithoutResponse
    // =====================================================================

    private class WriteWithoutResponseWrapper
            implements NamedJavaFunction {

        @Override
        public String getName() {

            return "writeWithoutResponse";
        }

        @Override
        public int invoke(
                LuaState L
        ) {

            String deviceId =
                    L.toString(1);

            String serviceUuid =
                    L.toString(2);

            String characteristicUuid =
                    L.toString(3);

            if (deviceId == null
                    || serviceUuid == null
                    || characteristicUuid == null
                    || L.isNoneOrNil(4)) {

                L.pushBoolean(false);

                return 1;
            }

            byte[] data;

            try {

                data =
                        L.toByteArray(4);

            } catch (Exception e) {

                L.pushBoolean(false);

                return 1;
            }

            if (data == null) {

                L.pushBoolean(false);

                return 1;
            }

            L.pushBoolean(
                    bleManager.writeWithoutResponse(
                            deviceId,
                            serviceUuid,
                            characteristicUuid,
                            data
                    )
            );

            return 1;
        }
    }

    // =====================================================================
    // subscribe
    // =====================================================================

    private class SubscribeWrapper
            implements NamedJavaFunction {

        @Override
        public String getName() {

            return "subscribe";
        }

        @Override
        public int invoke(
                LuaState L
        ) {

            String deviceId =
                    L.toString(1);

            String serviceUuid =
                    L.toString(2);

            String characteristicUuid =
                    L.toString(3);

            if (deviceId == null
                    || serviceUuid == null
                    || characteristicUuid == null) {

                L.pushBoolean(false);

                return 1;
            }

            L.pushBoolean(
                    bleManager.subscribe(
                            deviceId,
                            serviceUuid,
                            characteristicUuid
                    )
            );

            return 1;
        }
    }

    // =====================================================================
    // unsubscribe
    // =====================================================================

    private class UnsubscribeWrapper
            implements NamedJavaFunction {

        @Override
        public String getName() {

            return "unsubscribe";
        }

        @Override
        public int invoke(
                LuaState L
        ) {

            String deviceId =
                    L.toString(1);

            String serviceUuid =
                    L.toString(2);

            String characteristicUuid =
                    L.toString(3);

            if (deviceId == null
                    || serviceUuid == null
                    || characteristicUuid == null) {

                L.pushBoolean(false);

                return 1;
            }

            L.pushBoolean(
                    bleManager.unsubscribe(
                            deviceId,
                            serviceUuid,
                            characteristicUuid
                    )
            );

            return 1;
        }
    }

    // =====================================================================
    // Corona runtime lifecycle
    // =====================================================================

    @Override
    public void onLoaded(
            CoronaRuntime runtime
    ) {
    }

    @Override
    public void onStarted(
            CoronaRuntime runtime
    ) {
    }

    @Override
    public void onSuspended(
            CoronaRuntime runtime
    ) {
    }

    @Override
    public void onResumed(
            CoronaRuntime runtime
    ) {
    }

    @Override
    public void onExiting(
            CoronaRuntime runtime
    ) {

        bleManager.destroy();

        if (listenerReference !=
                CoronaLua.REFNIL) {

            CoronaLua.deleteRef(
                    runtime.getLuaState(),
                    listenerReference
            );

            listenerReference =
                    CoronaLua.REFNIL;
        }
    }
}