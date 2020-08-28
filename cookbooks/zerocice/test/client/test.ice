#pragma once

module Demo {
   interface HelloWorld {
     ["ami", "amd"] string salute (string filename, out string data);
   };
};