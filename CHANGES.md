# Changes to Stapfen


## 2.0.1

* More verbose exit handlers
* Invoke `java.lang.System.exit` on the JVM when exiting

## 2.0.0

* Add support for JMS-backed `Stapfen::Worker` classes
* Deep copy the configuration passed into `Stomp::Client` to work-around [stomp #80](https://github.com/stompgem/stomp/issues/80)
* Support per-instance log configuration [#3](https://github.com/lookout/stapfen/issues/3)
