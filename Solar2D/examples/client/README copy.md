### Stato dell'App e Note sui Test

Ai fini dei test, la serratura deve essere ripristinata e nuova in modo che la password predefinita `123456` sia attiva, mentre attualmente l'app si connette manualmente aggiornando l'indirizzo MAC tramite `Constants.LOCK_MAC = "15:6E:16:FD:32:A6"` in `constants.lua`. Sebbene esista un'API BLE per la ricerca delle serrature e il recupero dei nomi dei dispositivi, al momento richiede miglioramenti nella logica, nella gestione della memoria e nell'interfaccia utente, motivo per cui l'inserimento manuale del MAC viene utilizzato esclusivamente per i test in questo momento.

Inoltre, l'app crea un file `ttlock.json` a ogni connessione: ciò significa che è necessario cancellare i dati dell'app o reinstallarla per garantire un valore pulito. Questa procedura è richiesta solo per i test attuali, in attesa di implementare una logica migliore in futuro.

---

### Come Usare il Plugin

1. **Posizione dei File Sorgente:** I file sorgente del plugin si trovano nella cartella `com.simahojr.ble`.
2. **Installazione:** Copia il file `\com.simahojr.ble\plugins\android\data.tgz` e incollalo in `$env:APPDATA\Solar2DPlugins\com.simahojr\plugin.ble\android`.
3. **Configurazione:** Ora puoi usare `plugin.ble` (assicurati che qualsiasi modifica sia correttamente riflessa in `build.settings`).
4. **Esecuzione dei Test:** I test attuali si concentrano sul protocollo TTLock; controlla la cartella `ttlock` per eseguire i test e il debug.


saved for personal C&P testing
$dest = "$env:APPDATA\Solar2DPlugins\com.simahojr\plugin.ble\android"

New-Item -ItemType Directory -Force $dest | Out-Null

Copy-Item `
    "D:\ttlock_ble\com.simahojr.ble\plugins\android\data.tgz" `
    "$dest\data.tgz" `
    -Force

adb install .\ttlock_ble.apk
adb logcat -c
adb logcat | Select-String "Corona"