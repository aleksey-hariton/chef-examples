# Chef YAML Recipes

Chef YAML recipes are a feature that was released in Chef 16. The goal of YAML recipes is to give novice users the ability to write simple recipes using YAML instead of the full-featured Ruby DSL.

The only existing documentation at the time of writing can be found here: https://docs.chef.io/release_notes_client/#yaml-recipes

## Folder structure

The folder structure for YAML recipes is the same as a normal cookbook except within the recipes directory, the files will have a `.yml` extension. Each recipe with a `.yml` extension will be named according to the file name. In the example below, the recipe would be referenced as `yaml_recipe_example::apache2` from a runlist. You can also have standard Ruby recipes in the same directory.

Here is an example with some files removed for brevity:

```
yaml_recipe_example
├── Policyfile.rb
├── kitchen.yml
├── metadata.rb
├── recipes
│   ├── apache2.yml
│   └── default.rb
```

Alternatively, you can also place a `recipe.yml` file in the root of the cookbook directory and omit the recipes directory. This recipe will be assigned the name `default` when it is used in a runlist. You cannot have multiple recipes when using this strategy.

```
yaml_recipe_example
├── Policyfile.rb
├── kitchen.yml
├── metadata.rb
├── recipe.yml
```

## Recipe YAML Syntax

The YAML syntax for a cookbook recipe uses a top level array of resources and each resource's structure can be derived from the Ruby DSL's equivalent properties. This is done by listing the desired property from the Ruby DSL as the key and the value as the equivalent YAML representation of the value.

For example:

```
resources:
- name: package[apache2]

- type: "directory"
  name: "/var/www/html" # string
  mode: 755 # integer
  recursive: true # boolean
  action: # array of strings
  - create
```

Will yield:

```
package "apache2"

directory "/var/www/html" do
  mode 755
  recursive true
  action ["create"]
end
```

YAML recipe is ERB template, like other tepmlates in Chef, so you can use all its features:

```
resources:
<%- if node['platform_family'] == 'debian' %>
- name: package[apache2]
<%- else %>
- name: package[httpd]
<%- end %>

<%- value = "Chef rocks!" %>
- name: file[/etc/someconfig]
  content: |
    # Generated by Chef cookbook <%= cookbook_name %>
    option = <%= value %>
```

### Guards

Some common resource functionality is also supported, provided that the value of a property can be expressed as one of the 4 primitive types (string, integer, boolean, array). That means it is possible to use `only_if` or `not_if` guards as long as they shell-out to bash or powershell.

```
resources:
- type: "directory"
  name: "/var/www/html"
  only_if: "which apache2"
```

You can use ERB ruby blocks, but only if they're returning boolean value

```
resources:
- type: "directory"
  name: "/var/www/html"
  only_if: "<%= ::File.exist?('/usr/sbin/apache2') %>"
```

Last string will produce following Ruby code if file exist:

```
  only_if "true"
```

Which is proper BASH command.

### notifies/subscribes

You can use `notifies/subscribes` for your resources:

```
- name: package[nginx]
- name: service[nginx]
  subscribes: 
    - restart
    - package[nginx]
    - delayed
  action:
    - enable
    - start
- name: file[/etc/nginx/conf.d/vhost.conf]
  notifies:
    - reload
    - service[nginx]
    - delayed
```

## Knife yaml convert

Along with YAML recipes, Chef 16 added a knife command for converting YAML recipes to the Ruby DSL equivalent. This is helpful when debugging issues with a YAML recipe or for when you need to start using more advanced features that are not available in the YAML recipe format.

Converting of YAML files with ERB not supported yet.

```
$ knife yaml convert recipes/apache2.yml
Converted 'recipes/apache2.yml' to 'recipes/apache2.rb'
```

## What is not currently supported?

Since YAML recipes are currently intended for users who are not familiar with Ruby, some functionality that relies on Ruby values is not available.

Some notable things not supported:

- Including recipes with `include_recipe`, `load_recipe`
- Resources with properties that accept a block, hash or a set of method parameters
  - For example the `ruby_script` resource is not supported because you must supply the `block` parameter
- Common resource properties that accept a block, hash or a set of method parameters
  - arguments to guards and `guard_interpreter`
  - guards that use ruby (directly, see above)
  - `lazy`
  - windows file security
