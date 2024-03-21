#
#
#

.SECONDEXPANSION:

MAKE_GOAL ?= help
.DEFAULT_GOAL := $(MAKE_GOAL)

QUIET := @

Default_flags := \
 -Wall \
 -Werror \
 +nowarn_export_all \
 +nowarn_deprecated_function \
 +debug_info

Compiler_flags := $(or $(ERLC_FLAGS),$(Default_flags))

empty:=
space:=$(empty) $(empty)
bullet:=$(space)$(space)*$(space)
define newline

$(space)$(space)$(space)$(space)$(space)$(space)$(space)$(space)
endef

bullet_list = \
    $(foreach item, \
      $(or $($(*)),[NONE]), \
      $(info $(bullet)$(item)))

variable_prefixes := \
  Modules_of_ Tests_of_

Build_output_dir := _build/default/lib
Test_output_dir := _build/test/lib

var_with_prefix = $(value:%=$(prefix)%)


display = $(foreach prefix, $(variable_prefixes), \
  $(info ==== $(var_with_prefix) === ) $(foreach item, \
    $(or $($(var_with_prefix)),[NONE]), \
      $(info $(bullet)$(item)) \
      $(foreach subprefix, Source_of_ Target_of_, \
        $(foreach subitem, $(subprefix:%=%$(item)), \
          $(info $(space)$(space)$(bullet)$(subitem) = $(newline)$($(subitem)))))))

include_dirs = $(wildcard ./lib/*/include)
Include_dirs := $(include_dirs:%=-I %)

More_libs := \
 amqp_client \
 credentials_obfuscation \
 decimal \
 jsx \
 meck \
 mochiweb \
 mq_series \
 parse_trans \
 rabbit_common \
 ranch \
 recon \
 settlement \
 tcp_rpc \
 tcp_rpc_client \
 tcp_rpc_serve \
 triq

Library_dirs := $(More_libs:%=-pa $(Build_output_dir)/%/ebin) \
 $(include_dirs:%/include=-pa %)

App_src_paths := $(wildcard ./lib/*/src/*.app.src)
App_src_files := $(notdir $(App_src_paths))
App_names := $(sort $(App_src_files:%.app.src=%))

path_app_src = $(wildcard $(app_name:%=lib/%-*/src)) \
  $(wildcard $(app_name:%=lib/%/src))
paths_erl = $(wildcard $(path_app_src:%=%/*.erl))
files_erl = $(notdir $(paths_erl))
modules_of_app_name = $(files_erl:%.erl=%)

path_app_test = $(wildcard $(app_name:%=lib/%-*/test)) \
  $(wildcard $(app_name:%=lib/%/test))
paths_test = $(wildcard $(path_app_test:%=%/*.erl))
files_test = $(notdir $(paths_test))
tests_of_app_name = $(files_test:%.erl=%)

$(foreach app_name,\
  $(App_names),\
  $(eval Source_dir_of_$(app_name) := $(path_app_src)) \
  $(eval Source_test_dir_of_$(app_name) := $(path_app_test)) \
  $(eval Target_dir_of_$(app_name) := $(app_name:%=$(Build_output_dir)/%/ebin)) \
  $(eval Target_test_dir_of_$(app_name) := $(app_name:%=$(Test_output_dir)/%/test)) \
  $(eval Modules_of_$(app_name) := $(modules_of_app_name)) \
  $(eval Tests_of_$(app_name) := $(tests_of_app_name)))

source_of_mod_name = $(Source_dir_of_$(app_name):%=%/$(mod_name:%=%.erl))
target_of_mod_name = $(Target_dir_of_$(app_name):%=%/$(mod_name:%=%.beam))

$(foreach app_name,\
   $(App_names),\
   $(foreach mod_name,\
      $(modules_of_app_name),\
      $(eval Source_of_$(mod_name) := $(source_of_mod_name)) \
      $(eval Target_of_$(mod_name) := $(target_of_mod_name)) \
      $(eval App_with_$(mod_name) := $(app_name))))


source_of_test_name = $(Source_test_dir_of_$(app_name):%=%/$(test_name:%=%.erl))
target_of_test_name = $(Target_test_dir_of_$(app_name):%=%/$(test_name:%=%.beam))

$(foreach app_name,\
   $(App_names),\
   $(foreach test_name,\
      $(tests_of_app_name),\
      $(eval Source_of_$(test_name) := $(source_of_test_name)) \
      $(eval Target_of_$(test_name) := $(target_of_test_name)) \
      $(eval App_with_$(test_name) := $(app_name))))

?%.build:
	$(info Application variables for $*)
	$(foreach value, $(*), $(display))



show_dia_rels = $(App_names)

?%.dialyzer:
	$(info Application $* appears in releases:)
	$(foreach in,$(show_dia_rels),$(info $(bullet)$(in)))

# ./_build/default/lib/$(APP)/ebin/%(MOD).beam: ./lib/$(APP)-*/src/$(MOD).erl

plt_modules = $($(plt_app)_module)
plt_beams = $(plt_modules:%=$(plt_ebin)%.beam)

Dialyzer_dir := dialyzer

Dialyzer_warnings := underspecs no_improper_lists no_undefined_callbacks

Dialyzer_OTP_apps := \
  erts kernel stdlib compiler mnesia \
  crypto sasl eunit tools inets snmp \
  xmerl ssl

# runtime_tools public_key asn1

#  odbc is not available -- Erlang/OTP ./configure --without-odbc

Dialyzer_Libraries := \
 mochiweb jsx tcp_rpc_server tcp_rpc_client amqp_client mq_series decimal meck

dialyzer_OTP_files = $(Dialyzer_OTP_apps:%=$(Dialyzer_dir)/%.plt)
dialyzer_log_file = $(*:%=$(Dialyzer_dir)/%.log)
dialyzer_plt_file = $(*:%=$(Dialyzer_dir)/%.plt)

dialyzer_apps = $(or \
  $(App_with_$*:%=$(Build_output_dir)/%/ebin),\
  $(*:%=$(Build_output_dir)/%/ebin))

.PRECIOUS: $(Dialyzer_dir)/%.plt

build_mod_name = $(notdir $(*:%.beam=%))
build_source_file = $($(build_mod_name:%=Source_of_%))
build_output = $(dir $@)

.PRECIOUS: %.beam

%.beam: $$(build_source_file)
	$(info $(space)$(space)ERLC $^)
	$(QUIET)mkdir -p $(build_output)
	$(QUIET)ERL_LIBS=lib erlc \
	$(Library_dirs) \
	$(Include_dirs) \
	$(Compiler_flags) \
	-o $(build_output:%/=%) \
	$^

build_beam_target = $(Target_of_$*)

%.build_beam: $$(build_beam_target) ;

modules_of_target = $(Modules_of_$*) $(Tests_of_$*)
build_beams_of_app = \
  $(foreach module, $(modules_of_target),\
    $(module:%=%.build_beam))

%.build: $$(build_beams_of_app) ;

build: $(App_names:%=%.build) ;

beams_of_application = \
  $(foreach module, $(modules_of_target),\
    $(Target_of_$(module)))

?beams_of_%: $$(beams_of_application)
	$(info Build files of application $(*))
	$(foreach prerequisite, $(or $^,[NONE]),\
	  $(info $(bullet)$(prerequisite)))

source_of_application = \
  $(foreach module, $(modules_of_target),\
    $(Source_of_$(module)))

?source_of_%: $$(source_of_application)
	$(info Source files of application $(*))
	$(foreach prerequisite, $(or $^,[NONE]),\
	  $(info $(bullet)$(prerequisite)))
#
# Unit tests
#
Eunit_dir := unit_test_logs

eunit_eval = 'eunit:test($(*),[verbose])'

eunit_libs = \
 $(More_libs:%=-pa $(Build_output_dir)/%/ebin) \
 $(App_names:%=-pa $(Build_output_dir)/%/ebin) \
 $(dir $(Target_of_$(*F)))

eunit_dep_build = $(App_with_$(*F):%=%.build)

.PRECIOUS: $(Eunit_dir)/%.eunit

eunit_app_name = $(App_with_$(*F))
eunit_modules = $(Modules_of_$(eunit_app_name)) $(*F)
eunit_dependencies = \
 $(foreach module, \
   $(eunit_modules), \
   $(Target_of_$(module)))

$(Eunit_dir)/%.eunit: $$(eunit_dependencies)
	$(info $(space)$(space)EUNIT $*)
	$(QUIET)mkdir -p "$(@D)" && \
	erl -noshell $(eunit_libs) \
	    -eval $(eunit_eval) \
	    -s init stop \
	    > $(@) 2>&1

%.eunit: $(Eunit_dir)/%.eunit;

test_dep_eunit = $(Tests_of_$(*):%=$(Eunit_dir)/%.eunit)

%.tests: $$(test_dep_eunit);

%.clean_testlog:
	$(QUIET)rm -f "$(*:%=$(Eunit_dir)/%.eunit)"

#
# Dialyzer
#
#$(Dialyzer_dir)/%.plt: $$(beams_of_application)
%.dialyzer: $$(beams_of_application)
	$(QUIET)mkdir -p $(Dialyzer_dir) && dialyzer \
	$(Dialyzer_warnings:%=-W%) \
	--build_plt \
	--output $(dialyzer_log_file) \
	--get_warnings \
	--apps $(beams_of_application) \
	--verbose \
	--output_plt $(dialyzer_plt_file) \
	|| ([ $$? -eq 2 ] && echo "Warnings admitted, continuing..." || exit 1)

$(Dialyzer_dir)/Erlang-OTP.plt:
	mkdir -p $(Dialyzer_dir) && dialyzer \
	--build_plt \
	--output_plt $(@) \
	--apps $(Dialyzer_OTP_apps)

$(Dialyzer_dir)/Libraries.plt:
	mkdir -p $(Dialyzer_dir) && dialyzer \
	--build_plt \
	--output_plt $(@) \
	--apps $(Dialyzer_Libraries:%=$(Build_output_dir)/%/ebin)

#%.dialyzer: $(Dialyzer_dir)/%.plt;

Analysis_plts := \
  $(Dialyzer_dir)/Erlang-OTP.plt \
  $(Dialyzer_dir)/Libraries.plt \
  $(App_names:%=$(Dialyzer_dir)/%.plt)

.PRECIOUS: $(Dialyzer_dir)/%.analysis

#
# TODO: For analysis targets, need to specify only updated PLT files
#       dependent on what BEAM files were rebuilt. Not easy, as some apps
#       depend on other apps for comprehensive analysis.
#
$(Dialyzer_dir)/%.analysis: $(Analysis_plts)
	dialyzer \
	$(Dialyzer_warnings:%=-W%) \
	--no_check_plt \
	--verbose \
	--output $@ \
	--plts $(Analysis_plts) \
	-- $(*:%=$(Build_output_dir)/%/ebin) \
	|| ([ $$? -eq 2 ] && echo "Warnings admitted, continuing..." || exit 1)

%.analyse: $(Dialyzer_dir)/%.analysis;

Analysis_targets := $(App_names:%=%.analyse)

.PHONY: analyse
analyse: build $(Analysis_targets)

?%:
	$(info Values assigned to $(*))
	$(bullet_list)

.PHONY: help
help:
	$(info Dialyzer Makefile. Recommend using --jobs=N for highest speed. )
	$(info Use the command:)
	$(info $(bullet)make analyse)
	$(info to perform a full Dialyser analysis of the source code;)
	$(info $(bullet)make help.targets)
	$(info to reveal all possible targets that this Makefile can produce;)
	$(info $(bullet)make ?...)
	$(info to reveal the value stored in a variable, e.g. make ?App_names)

All_targets := ? help dialyzer analyse $(Dialyzer_targets) $(Analysis_targets)

.PHONY: help.targets
help.targets:
	$(info The following targets are provided:)
	$(foreach target, $(All_targets),\
	    $(info $(bullet)$(target)))

%.clean_beam:
	$(QUIET)rm -f "$(Target_of_$*)"

delete_files_of_app = \
  $(foreach module, $(modules_of_target),\
    $(module:%=%.clean_beam)) \
  $(foreach testlog, $(Tests_of_$(*)),\
    $(testlog:%=%.clean_testlog))

%.clean: $$(delete_files_of_app);

.PHONY: clean
clean: $(App_names:%=%.clean)
	rm -r "$(Eunit_dir)"
