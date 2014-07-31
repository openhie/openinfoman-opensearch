openinfoman-opensearch
======================

Library to add OpenSearch support of CSD documents to the OpenInfoMan
s FHIR organization

Prerequisites
=============

Assumes that you have installed BaseX and OpenInfoMan according to:
> https://github.com/openhie/openinfoman/wiki/Install-Instructions


Directions
==========
To get the libarary:
<pre>
cd ~/
git clone https://github.com/openhie/openinfoman-opensearch
</pre>

Library Module
--------------
Common functionality for the is packaged in an XQuery module
<pre>
cd ~/basex/repo
basex -Vc "REPO INSTALL openinfoman_opensearch_adapter.xqm"
</pre>


Stored Functions
----------------
To install the stored functions (one for each of the FHIR resources) you can do: 
<pre>
cd ~/basex/resources/stored_query_definitions
ln -sf ~/openinfoman-opensearch/resources/stored_query_definitions/* .
</pre>
Be sure to reload the stored functions: 
> https://github.com/openhie/openinfoman/wiki/Install-Instructions#Loading_Stored_Queries


OpenSearch Endpoints
--------------
You can the stored functions to the GET endpoints requried by OpenSearch with:  
<pre>
cd ~/basex/webapp
ln -sf ~/openinfoman-opensearch/webapp/openinfoman_opensearch_bindings.xqm
</pre>

