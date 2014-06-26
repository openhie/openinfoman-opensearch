import module namespace osf = "https://github.com/his-interop/openinfoman/opensearch_feed";
import module namespace functx = 'http://www.functx.com';

declare namespace csd =  "urn:ihe:iti:csd:2013";
declare namespace rss = "http://backend.userland.com/rss2";
declare namespace atom = "http://www.w3.org/2005/Atom";
declare namespace html = "http://www.w3.org/1999/xhtml";
declare namespace os  = "http://a9.com/-/spec/opensearch/1.1/";

declare variable $careServicesRequest as item() external;



(: 
   The query will be executed against the root element of the CSD document.    
   The dynamic context of this query has $careServicesRequest set to contain any of the search 
   and limit paramaters as sent by the Service Finder
:) 


(:Get the search terms passed in the request :)
let $search_terms := xs:string($careServicesRequest/os:searchTerms/text())
(:Find the matching providers -- to be customized for your search:)
let $matched_providers :=  
  for $provider in /csd:CSD/csd:providerDirectory/csd:provider
  let $common_name := $provider/csd:demographic/csd:name/csd:commonName
  where  exists($search_terms) and exists($common_name) and functx:contains-case-insensitive($common_name,  $search_terms)  
  return $provider  



(:Produce the feed in the neccesary format :)
return osf:create_feed_from_entities($matched_providers,$careServicesRequest)



