document-modules.py

WHAT IS document-modules.py?

  This is a python script designed to create a html file to document callable 
  objects inside the module:

	* classes (class tree)
	* functions (args, varargs, keyword, defaults)
	* methods

  This module was written to documment an undocumented and unsupported vSphere
  python API included in VMware ESXi.

  It is very important to run this script with the same python version the python
  module was written for.

  For instance if we run:

    /usr/bin/python2.6 document-modules.py /usr/lib/pymodules/python2.6/numpy numarray session.py

  a numarray.session.html will be created with information about:

	/usr/lib/pymodules/python2.6/numpy/numarray/session.py

  However, if we run:

    /usr/bin/python2.6 document-modules.py /usr/lib/pymodules/python2.6/numpy . dual.pyc

  a dual.html will be created with information about:

        /usr/lib/pymodules/python2.6/numpy/dual.pyc

_______________________________________________________________________
 (c) 2013 Jose Angel de Bustos Perez <jadebustos@gmail.com> 
     Distributed under GNU GPL v2 License                   
     See COPYING.txt for more details  
