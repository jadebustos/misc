# Zero Ice

Simple examples of how to develop distributed apps using Zeroc Ice.

* grid-async, asynchronous application to be executed by Zeroc Ice Grid.
* grid-sync, synchronous application to be executed by Zeroc Ice Grid.
* grid-sync-reply, asynchronous application to be executed by Zeroc Ice Grid. This application returns information to the client.
* standalone-sync, synchronous application to be executed manually.

# Zeroc Ice infrastructure

By default the infrastructure used will be:

----------------------------
| Client (192.168.100.9)   | 
----------------------------     
                                 
----------------------------     
| Worker1 (192.168.100.11) |
|                          | 
| Registry                 |
| Grid Node                |
----------------------------

----------------------------
| Worker2 (192.168.100.12) |
|                          |
| Grid Node                |
----------------------------
