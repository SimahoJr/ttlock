(function () {
    "use strict";

    /* DEFAULT CONFIGURATION */

    var DEFAULT_SECRETS_CONFIG = {
        lockId: 1048576,
        lockMac: "15:6E:16:FD:32:A6",
        key: "bcbf5375606fc0007a0428368b260a20",
        adminPassword: 123456,
        unlockKey: 123456,
        lockVersion: 3,
        aptName: "Carrubi",
        stanzaName: "St.1"
    };

    var TEST_USERNAME = "admin";
    var TEST_PASSWORD = "admin";
    var TEST_UNLOCK_DURATION = 5;

    var isProcessing = false;
    var isUnlocked = false;
    var countdownTimer = null;

    /* ELEMENTS */

    var loginPage = document.getElementById("loginPage");
    var configPage = document.getElementById("configPage");
    var lockPage = document.getElementById("lockPage");

    var loginForm = document.getElementById("loginForm");
    var usernameInput = document.getElementById("username");
    var passwordInput = document.getElementById("password");
    var loginButton = document.getElementById("loginButton");
    var qrCodeButton = document.getElementById("qrCodeButton");
    var qrFileInput = document.getElementById("qrFileInput");
    var qrCanvas = document.getElementById("qrCanvas");
    var ctx = qrCanvas.getContext("2d");
    var loginError = document.getElementById("loginError");

    var secretsJsonTextarea = document.getElementById("secretsJson");
    var saveConfigButton = document.getElementById("saveConfigButton");
    var configError = document.getElementById("configError");

    var lockTitle = document.getElementById("lockTitle");
    var unlockButton = document.getElementById("unlockButton");
    var unlockLabel = document.getElementById("unlockLabel");
    var processingText = document.getElementById("processingText");
    var activeStatus = document.getElementById("activeStatus");
    var countdown = document.getElementById("countdown");
    var batteryValue = document.getElementById("batteryValue");
    var unlockPasswordValue = document.getElementById("unlockPasswordValue");
    var passwordExpiryValue = document.getElementById("passwordExpiryValue");
    var signoutButton = document.getElementById("signoutButton");
    var debug = document.getElementById("debug");

    /* PAGE */

    function showPage(page) {
        loginPage.classList.remove("active");
        configPage.classList.remove("active");
        lockPage.classList.remove("active");

        if (page === "login") { loginPage.classList.add("active"); }
        if (page === "config") { configPage.classList.add("active"); }
        if (page === "lock") { lockPage.classList.add("active"); }
    }

    function savePageState(page) {
        try { sessionStorage.setItem("shannon_page", page); } catch (error) { console.error("[STATE] Save error:", error); }
    }

    function getPageState() {
        try { return sessionStorage.getItem("shannon_page") || "login"; } catch (error) { return "login"; }
    }

    function clearPageState() {
        try { sessionStorage.removeItem("shannon_page"); } catch (error) {}
    }

    function resetUnlockState() {
        isProcessing = false;
        isUnlocked = false;

        if (countdownTimer) { clearInterval(countdownTimer); countdownTimer = null; }

        unlockButton.classList.remove("processing", "unlocked");
        unlockLabel.textContent = "UNLOCK";
        processingText.textContent = "";
        activeStatus.textContent = "";
        countdown.textContent = "";
    }

    function setProcessingState() {
        isProcessing = true;
        isUnlocked = false;

        savePageState("lock");
        showPage("lock");

        unlockButton.classList.add("processing");
        unlockButton.classList.remove("unlocked");

        unlockLabel.textContent = "PROCESSING";
        processingText.textContent = "Processing...";
        activeStatus.textContent = "";
        countdown.textContent = "";
    }

    function setUnlockedState(duration) {
        isProcessing = false;
        isUnlocked = true;

        savePageState("lock");
        showPage("lock");

        unlockButton.classList.remove("processing");
        unlockButton.classList.add("unlocked");

        unlockLabel.textContent = "UNLOCKED";
        processingText.textContent = "";
        activeStatus.textContent = "ACCESS ACTIVE";

        var remaining = Number(duration) || 0;

        if (countdownTimer) { clearInterval(countdownTimer); countdownTimer = null; }

        countdown.textContent = remaining + "s";
        if (remaining <= 0) { return; }

        countdownTimer = setInterval(function() {
            remaining--;

            if (remaining <= 0) {
                clearInterval(countdownTimer);
                countdownTimer = null;
                resetUnlockState();
                unlockButton.classList.remove("unlocked");
                savePageState("lock");
                showPage("lock");
                return;
            }

            countdown.textContent = remaining + "s";
        }, 1000);
    }

    function setUnlockFailed(message) {
        isProcessing = false;
        isUnlocked = false;

        savePageState("lock");
        showPage("lock");

        unlockButton.classList.remove("processing", "unlocked");
        unlockLabel.textContent = "UNLOCK";
        processingText.textContent = "";
        activeStatus.textContent = message || "UNLOCK FAILED";
        countdown.textContent = "";
    }

    function restorePageState() {
        var page = getPageState();

        if (page === "lock") {
            showPage("lock");
            return;
        }

        if (page === "config") {
            showPage("config");
            return;
        }

        showPage("login");
    }

    /* JS -> LUA */

    window.sendNative = function(command, payload) {
        try {
            if (!command || !String(command).trim()) { console.error("[JS -> LUA] Invalid command:", command); return; }

            command = String(command).trim();

            if (!payload || typeof payload !== "object") { payload = {}; }

            payload.timestamp = Date.now();
            payload.random = Math.floor(Math.random() * 1000000000);

            if (command === "unlock") { setProcessingState(); }

            if (command === "login" || command === "qrcode") { savePageState("login"); }
            if (command === "get_secrets") { savePageState("config"); }
            if (command === "save_secrets") { savePageState("lock"); }

            var jsonPayload = JSON.stringify(payload);
            var url = "index.html?bridge=" + encodeURIComponent(command) + "&payload=" + encodeURIComponent(jsonPayload);

            console.log("[JS -> LUA] Command:", command);
            console.log("[JS -> LUA] Payload:", jsonPayload);
            console.log("[JS -> LUA] URL:", url);

            window.location.replace(url);
        } catch (error) {
            console.error("[JS] Native bridge error:", error);
        }
    };

    /* LOGIN */

    loginButton.addEventListener("click", function() {
        loginError.textContent = "";

        var username = usernameInput.value.trim();
        var password = passwordInput.value;

        if (!username) { loginError.textContent = "Username is required."; return; }
        if (!password) { loginError.textContent = "Password is required."; return; }

        loginButton.disabled = true;
        loginButton.textContent = "SIGNING IN...";

        if (username === TEST_USERNAME && password === TEST_PASSWORD) {
            window.sendNative("login", { username: username, isTest: true });
            return;
        }

        window.sendNative("login", { username: username, password: password });
    });

    loginForm.addEventListener("submit", function(event) {
        event.preventDefault();
        loginButton.click();
        return false;
    });

    /* QRCODE CAMERA SCANNING */

    qrCodeButton.addEventListener("click", function() {
        loginError.textContent = "";
        qrFileInput.click();
    });

    qrFileInput.addEventListener("change", function(e) {
        var file = e.target.files[0];
        if (!file) return;

        var reader = new FileReader();
        reader.onload = function(event) {
            var img = new Image();
            img.onload = function() {
                qrCanvas.width = img.width;
                qrCanvas.height = img.height;
                ctx.drawImage(img, 0, 0);

                var imageData = ctx.getImageData(0, 0, qrCanvas.width, qrCanvas.height);
                var code = jsQR(imageData.data, imageData.width, imageData.height);

                if (code) {
                    console.log("[JS] QR Code detected:", code.data);
                    window.sendNative("qrcode", { code: code.data });
                } else {
                    loginError.textContent = "Could not read QR code. Try again.";
                }
                qrFileInput.value = "";
            };
            img.src = event.target.result;
        };
        reader.readAsDataURL(file);
    });

    /* SAVE CONFIGURATION */

    saveConfigButton.addEventListener("click", function() {
        configError.textContent = "";

        try {
            var config = JSON.parse(secretsJsonTextarea.value);

            if (!config || typeof config !== "object") { throw new Error("Invalid configuration"); }

            saveConfigButton.disabled = true;
            saveConfigButton.textContent = "SAVING...";

            window.sendNative("save_secrets", config);
        } catch (error) {
            configError.textContent = "Invalid JSON format. Please correct it.";
        }
    });

    /* UNLOCK */

    unlockButton.addEventListener("click", function() {
        if (isProcessing || isUnlocked) { return; }

        setProcessingState();
        window.sendNative("unlock", {});
    });

    /* SIGN OUT */

    signoutButton.addEventListener("click", function() {
        clearPageState();
        resetUnlockState();

        usernameInput.value = "";
        passwordInput.value = "";
        loginError.textContent = "";
        loginButton.disabled = false;
        loginButton.textContent = "SIGN IN";

        window.sendNative("logout", {});
    });

    /* LUA -> JS */

    window.handleNativeEvent = function(event) {
        if (!event || !event.type) { return; }

        if (event.type === "auth_success") {
            configError.textContent = "";
            secretsJsonTextarea.value = "";
            savePageState("config");
            window.sendNative("get_secrets", {});
            return;
        }

        if (event.type === "auth_error") {
            loginButton.disabled = false;
            loginButton.textContent = "SIGN IN";
            loginError.textContent = event.message || "Login failed";
            savePageState("login");
            showPage("login");
            return;
        }

        if (event.type === "secrets_result") {
            var hasSecrets = event.lockId !== undefined && event.lockId !== null && event.lockId !== 0;

            if (hasSecrets) {
                var aptName = event.aptName || DEFAULT_SECRETS_CONFIG.aptName;
                var stanzaName = event.stanzaName || DEFAULT_SECRETS_CONFIG.stanzaName;

                secretsJsonTextarea.value = JSON.stringify({
                    lockId: event.lockId,
                    lockMac: event.lockMac || "",
                    key: event.key || "bcbf5375606fc0007a0428368b260a20",
                    adminPassword: event.adminPassword || 0,
                    unlockKey: event.unlockKey || 0,
                    lockVersion: event.lockVersion || "",
                    aptName: aptName,
                    stanzaName: stanzaName
                }, null, 4);

                lockTitle.textContent = aptName + " " + stanzaName;
            } else {
                secretsJsonTextarea.value = JSON.stringify(DEFAULT_SECRETS_CONFIG, null, 4);
                lockTitle.textContent = DEFAULT_SECRETS_CONFIG.aptName + " " + DEFAULT_SECRETS_CONFIG.stanzaName;
            }

            savePageState("config");
            showPage("config");
            return;
        }

        if (event.type === "save_secrets_save_success") {
            saveConfigButton.disabled = false;
            saveConfigButton.textContent = "SAVE & CONTINUE";
            savePageState("lock");
            showPage("lock");
            return;
        }

        if (event.type === "save_secrets_error") {
            saveConfigButton.disabled = false;
            saveConfigButton.textContent = "SAVE & CONTINUE";
            configError.textContent = event.message || "Failed to save configuration.";
            savePageState("config");
            showPage("config");
            return;
        }

        if (event.type === "lock_process") {
            setProcessingState();
            return;
        }

        if (event.type === "unlock_result") {
            if (event.userPassword) { unlockPasswordValue.textContent = event.userPassword; }
            if (event.action === "unlock" && event.processing) {
                setProcessingState();
                return;
            }

            if (event.action === "unlock" && event.success) {
                setUnlockedState(event.unlockDuration);

                if (event.battery !== undefined) { batteryValue.textContent = event.battery + "%"; }
                if (event.passwordExpiry !== undefined) { passwordExpiryValue.textContent = event.passwordExpiry; }

                return;
            }

            if (event.action === "unlock" && event.success === false) {
                setUnlockFailed(event.message);
                return;
            }
        }

        if (event.type === "logout_success") {
            clearPageState();
            resetUnlockState();
            loginButton.disabled = false;
            loginButton.textContent = "SIGN IN";
            showPage("login");
            return;
        }

        if (event.type === "password_expiry") {
            if (event.passwordExpiry !== undefined) { passwordExpiryValue.textContent = event.passwordExpiry; }
            return;
        }
    };

    /* BRIDGE QUERY */

    try {
        var search = window.location.search || "";

        restorePageState();

        if (search) {
            var query = search.substring(1);
            var parts = query.split("&");
            var bridge = null;
            var payload = null;

            for (var i = 0; i < parts.length; i++) {
                var pair = parts[i].split("=");
                var key = pair.shift();
                var value = pair.join("=");

                if (key === "bridge") { bridge = decodeURIComponent(value); }
                if (key === "payload") { payload = decodeURIComponent(value); }
            }

            if (bridge && payload !== null) {
                console.log("[BRIDGE] Command:", bridge);
                console.log("[BRIDGE] Payload:", payload);
            }

            if (bridge && payload === null) {
                console.log("[BRIDGE] Event:", bridge);

                var event = JSON.parse(bridge);

                if (event && event.type) { window.handleNativeEvent(event); }
            }
        }
    } catch (error) {
        console.error("[BRIDGE] ERROR:", error);

        if (debug) {
            debug.style.display = "block";
            debug.textContent = "[BRIDGE ERROR]\n" + String(error);
        }
    }
})();