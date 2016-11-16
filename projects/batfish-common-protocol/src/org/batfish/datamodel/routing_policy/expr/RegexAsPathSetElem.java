package org.batfish.datamodel.routing_policy.expr;

import com.fasterxml.jackson.annotation.JsonCreator;

public class RegexAsPathSetElem implements AsPathSetElem {

   /**
    *
    */
   private static final long serialVersionUID = 1L;

   private String _regex;

   @JsonCreator
   public RegexAsPathSetElem() {
   }

   public RegexAsPathSetElem(String regex) {
      _regex = regex;
   }

   public String getRegex() {
      return _regex;
   }

   public void setRegex(String regex) {
      _regex = regex;
   }

}