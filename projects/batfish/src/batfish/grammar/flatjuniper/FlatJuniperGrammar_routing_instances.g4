parser grammar FlatJuniperGrammar_routing_instances;

import FlatJuniperGrammarCommonParser;

options {
   tokenVocab = FlatJuniperGrammarLexer;
}

agt_as_path
:
   AS_PATH PATH DEC
;

agt_preference
:
   PREFERENCE DEC
;

gt_discard
:
   DISCARD
;

gt_metric
:
   METRIC DEC
;

gt_policy
:
   POLICY policy = variable
;

rgt_import_rib
:
   IMPORT_RIB rib = VARIABLE
;

ribt_aggregate
:
   ribt_aggregate_header ribt_aggregate_tail
;

ribt_aggregate_header
:
   AGGREGATE ROUTE
   (
      IP_ADDRESS_WITH_MASK
      | IPV6_ADDRESS_WITH_MASK
   )
;

ribt_aggregate_tail
:
   agt_as_path
   | agt_preference
;

ribt_generate
:
   rot_generate
;

ribt_static
:
   rot_static
;

rit_apply_groups
:
   s_apply_groups
;

rit_common
:
   rit_apply_groups
   | rit_routing_options
;

rit_named_routing_instance
:
   (
      WILDCARD
      | name = variable
   ) rit_named_routing_instance_tail
;

rit_named_routing_instance_tail
:
   rit_common
;

rit_routing_options
:
   s_routing_options
;

rot_aggregate
:
   AGGREGATE ROUTE IP_ADDRESS_WITH_MASK
   (
      (
         AS_PATH ORIGIN IGP
      )
      |
      (
         COMMUNITY community = COMMUNITY_LITERAL
      )
      |
      (
         TAG tag = DEC
      )
   )*
;

rot_autonomous_system
:
   AUTONOMOUS_SYSTEM as = DEC
;

rot_martians
:
   MARTIANS s_null_filler
;

rot_generate
:
   rot_generate_header rot_generate_tail
;

rot_generate_header
:
   GENERATE ROUTE
   (
      IP_ADDRESS_WITH_MASK
      | IPV6_ADDRESS_WITH_MASK
   )
;

rot_generate_tail
:
   gt_discard
   | gt_metric
   | gt_policy
;

rot_null
:
   (
      FORWARDING_TABLE
      | MULTICAST
      | OPTIONS
   ) s_null_filler
;

rot_rib_groups
:
   rot_rib_groups_header rot_rib_groups_tail
;

rot_rib_groups_header
:
   RIB_GROUPS name = VARIABLE
;

rot_rib_groups_tail
:
   rgt_import_rib
;

rot_rib
:
   RIB name = VARIABLE rot_rib_tail
;

rot_rib_tail
:
   ribt_aggregate
   | ribt_generate
   | ribt_static
;

rot_router_id
:
   ROUTER_ID id = IP_ADDRESS
;

rot_static
:
   rot_static_header rot_static_tail
;

rot_static_header
:
   STATIC ROUTE
   (
      IP_ADDRESS_WITH_MASK
      | IPV6_ADDRESS_WITH_MASK
   )
;

rot_static_tail
:
   srt_discard
   | srt_install
   | srt_next_hop
   | srt_readvertise
   | srt_reject
   | srt_tag
;

s_routing_instances
:
   ROUTING_INSTANCES s_routing_instances_tail
;

s_routing_instances_header
:
   ROUTING_INSTANCES
;

s_routing_instances_tail
:
   rit_common
   | rit_named_routing_instance
;

s_routing_options
:
   ROUTING_OPTIONS s_routing_options_tail
;

s_routing_options_tail
:
   rot_aggregate
   | rot_autonomous_system
   | rot_generate
   | rot_martians
   | rot_null
   | rot_rib
   | rot_rib_groups
   | rot_router_id
   | rot_static
;

srt_discard
:
   DISCARD
;

srt_install
:
   INSTALL
;

srt_next_hop
:
   NEXT_HOP
   (
      IP_ADDRESS
      | IPV6_ADDRESS
   )
;

srt_readvertise
:
   READVERTISE
;

srt_reject
:
   REJECT
;

srt_tag
:
   TAG tag = DEC
;
