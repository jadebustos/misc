#pragma once

module Demo {
   interface HelloWorld {
     ["ami", "amd"] string salute (string clientHostname, out string serverHostname);
   };
};
