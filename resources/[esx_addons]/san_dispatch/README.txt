san_dispatch clean v120

Dette er en helt ny dispatch-resource fra bunden.
Den kræver kun din eksisterende san_mdt, fordi den sender til server-eventet:
  san_mdt:autoDispatchCall

Installer:
1. Stop serveren.
2. Slet/omdøb gamle san_dispatch mapper.
3. Udpak denne mappe så den hedder præcis: san_dispatch
4. server.cfg:
   ensure san_mdt
   ensure san_dispatch

Test ingame:
  /dispatchstatus
  /testdispatch
  /testdispatchserver
  /testallevents

Vigtigt:
- Foto er slået fra med vilje. screenshot-basic kan ikke tage et rigtigt NPC-vinkel foto uden at flytte spillerens kamera.
- Hvis du vil have foto senere, skal det enten være spillerens kamera eller et separat fake/placeholder-system.
- Våben i hånden har kun 18% chance efter NPC-vidne.
- Skud har 100% chance efter NPC-vidne.
- Vold mod NPC kan også anmeldes af offeret selv.
