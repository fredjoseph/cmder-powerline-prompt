-- This script is adapted from project : https://github.com/AmrEldib/cmder-powerline-prompt
local color = require('color')
local gitutil = require('gitutil')
local JSON = require("JSON")
local path = require("path")

-- ANSI Sequences (See https://en.wikipedia.org/wiki/ANSI_escape_code#Colors for color codes)
-- Format : Esc[Value;...;Valuem

-- Local functions
local function get_folder_name(path)
    local reversePath = string.reverse(path)
    local slashIndex = string.find(reversePath, "\\")
    return string.sub(path, string.len(path) - slashIndex + 2)
end

local function createTable(...)
    local table = {}
    local arg = {...}
    for _,v in ipairs(arg) do
        table[tostring(v)] = v
    end
    return table
end

local function get(table, key)
    return table[tostring(key)]
end

local function contains(table, key)
    return get(table, key) ~= nil
end

local function get_env_lowercase(var)
    local env_var = clink.get_env(var)
    return env_var and string.lower(env_var)
end

local function get_git_status()
    local file = io.popen("git --no-optional-locks status --porcelain 2>nul")
    for line in file:lines() do
        file:close()
        return false
    end
    file:close()
    
    return true
end

local function colored_text(text, foreground, background, bold)
    return color.set_color(foreground, background, bold)..text
end

-- Specific script constants
local PROMPT_FULL = "full"
local PROMPT_FOLDER = "folder"
local ARROW_SYMBOL = ""
local BRANCH_SYMBOL = ""
local PROMPT_END_CHAR = "λ"
local PROMPT_ADMIN_CHAR = "⚡"
local RESET_SEQ = "\x1b[0m"

local PROMPT_PATH_TYPES = createTable(PROMPT_FULL, PROMPT_FOLDER)
local TRUE_OR_FALSE = createTable(true, false)

local settings = {}
settings.path_type = get(PROMPT_PATH_TYPES, get_env_lowercase("CMDER_CUSTOM_PROMPT_PATH_TYPE")) or PROMPT_FULL
settings.display_admin = get(TRUE_OR_FALSE, get_env_lowercase("CMDER_CUSTOM_PROMPT_DISPLAY_ADMIN")) or false
settings.display_user = get(TRUE_OR_FALSE, get_env_lowercase("CMDER_CUSTOM_PROMPT_DISPLAY_USER")) or false
settings.tilde_substitution = get(TRUE_OR_FALSE, get_env_lowercase("CMDER_CUSTOM_PROMPT_TILDE_SUBSTITUTION")) or true

local old_prompt
local clink_cwd
local ascii_cwd

-- Filter Definitions
function reset_prompt_filter()
    old_prompt = clink.prompt.value
    
    local prompt_header = "{admin}{user}{cwd}{git}{npm}\x1b[K\x1b[0m"
    local prompt_lhs = "{env}{lamb} \x1b[0m"
    clink.prompt.value = prompt_header .. "\n" .. prompt_lhs
    
    clink.prompt.value = string.gsub(clink.prompt.value, "{lamb}", colored_text(PROMPT_END_CHAR, color.GREEN, color.BLACK, color.BOLD))
end

function admin_prompt_filter()
    if settings.display_admin then
        local _,_,ret = os.execute("net session 1>nul 2>nul")
        if ret == 0 then
            clink.prompt.value = string.gsub(clink.prompt.value, "{admin}", colored_text(PROMPT_ADMIN_CHAR, color.YELLOW, color.BLACK, color.BOLD)..RESET_SEQ.." ")
            return false;
        end
    end
    
    clink.prompt.value = string.gsub(clink.prompt.value, "{admin}", "")
end

function user_prompt_filter()
    if settings.display_user then
        local username = clink.get_env("USERNAME")
        local host = clink.get_env("COMPUTERNAME")
        
        clink.prompt.value = string.gsub(clink.prompt.value, "{user}", colored_text(username.."@"..host, color.WHITE, color.BLACK))
        return false
    end
    
    clink.prompt.value = string.gsub(clink.prompt.value, "{user}", "")
end

function cwd_prompt_filter()
    clink_cwd = clink.get_cwd()
    
    -- get_cwd() is differently encoded than the clink.prompt.value, so everything other than
    -- pure ASCII will get garbled. So try to parse the current directory from the original prompt
    -- and only if that doesn't work, use get_cwd() directly.
    -- The matching relies on the default prompt which ends in X:\PATH\PATH>
    -- (no network path possible here!)
    ascii_cwd = old_prompt:match('.*(.:[^>]*)>')
    local cwd = ascii_cwd or clink_cwd
    
    if settings.path_type == PROMPT_FOLDER then
        cwd = get_folder_name(cwd)
    elseif settings.tilde_substitution then
        local home_pattern = string.gsub(clink.get_env("userprofile"), "[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1")
        cwd = string.gsub(cwd, home_pattern, "~")
    end
    
    clink.prompt.value = string.gsub(clink.prompt.value, "{cwd}", colored_text(cwd, color.WHITE, color.BLUE))
end

function git_prompt_filter()
    local git_dir = gitutil.get_git_dir(clink_cwd)
    -- Ugly : 'get_git_dir' uses same encoding that clink.prompt.value, but 'get_git_branch' uses the encoding of 'clink.get_cwd()'
    -- No difference for paths whithout special characters (accent...)
    if not git_dir and clink_cwd ~= ascii_cwd then 
        git_dir = gitutil.get_git_dir(ascii_cwd)
        if git_dir then
            local path_separator_pattern = "[\\/]";
            local nb_separator_in_current_dir = select(2, string.gsub(clink_cwd, path_separator_pattern, ""))
            local nb_separator_in_git_dir = select(2, string.gsub(git_dir, path_separator_pattern, ""))
            
            local clink_cwd_git_dir = clink_cwd
            for i=nb_separator_in_current_dir,nb_separator_in_git_dir,-1 do clink_cwd_git_dir = path.pathname(clink_cwd_git_dir) end
            git_dir = clink_cwd_git_dir .. '/.git'
        end
    end
    
    if git_dir then
        -- if we're inside of git repo then try to detect current branch
        local branch = gitutil.get_git_branch(git_dir)
        if branch then
            -- Has branch => now figure out status
            local background_color = get_git_status() and color.GREEN or color.YELLOW
            
            clink.prompt.value = string.gsub(clink.prompt.value, "{git}", colored_text(BRANCH_SYMBOL.." "..branch, color.BLACK, background_color))
            return false
        end
    end

    -- No git present or not in git file
    clink.prompt.value = string.gsub(clink.prompt.value, "{git}", "")
end

-- Add PROMPT variable contents to the prompt (strip DOS symbols)
-- so virtual environments will be shown
function env_prompt_filter()
    local original_prompt = clink.get_env("PROMPT")
    local original_prompt_env = ""
    if original_prompt ~= nil then
        local c = string.find(original_prompt, "[$]")
        if c ~= nil then
            original_prompt_env = string.sub(original_prompt, 1, c - 1)
        end
    end
    
    clink.prompt.value = string.gsub(clink.prompt.value, "{env}", colored_text(original_prompt_env, color.GREEN, color.BLACK, color.BOLD))
end

-- Adapted from 'npm.lua'
local function npm_prompt_filter()
    local function npm_substitute_builder()
        local package_file = io.open('package.json')
        if not package_file then return "" end
        
        local package_data = package_file:read('*a')
        package_file:close()
        
        local package = JSON:decode(package_data)
        if not package then return "" end
        
        -- Don't print package info when the package is private or both version and name are missing
        if package.private or (not package.name and not package.version) then return "" end
        
        local package_name = package.name or "<no name>"
        local package_version = package.version and "@"..package.version or ""
        return colored_text("("..package_name..package_version..")", color.YELLOW, color.BLACK)
    end
    
    clink.prompt.value = clink.prompt.value:gsub('{npm}', npm_substitute_builder)
end

-- Add 'Arrow' character to each background color change
function agnoster_filter()
    local COLOR_PATTERN = "(\x1b[^m]-m)"
    local BACK_COLOR_PATTERN = "4(%d)"
    local RESET_COLOR_PATTERN = "(0)m"
    local current_back_color = nil
    local function arrow_inserter(current_seq)
        local new_back_color = tonumber(string.match(current_seq, BACK_COLOR_PATTERN) or string.match(current_seq, RESET_COLOR_PATTERN))
        if not current_back_color then
            current_back_color = new_back_color or color.BLACK
        end
        
        local substitute_text = current_seq
        if new_back_color ~= current_back_color then
            substitute_text = colored_text(ARROW_SYMBOL.." "..substitute_text, current_back_color, new_back_color)
            current_back_color = new_back_color
        end
        
        if current_seq == RESET_SEQ then
            current_back_color = nil
        end

        return substitute_text
    end
    
    clink.prompt.value = string.gsub(clink.prompt.value, COLOR_PATTERN, arrow_inserter)
end

-- override the built-in filters
clink.prompt.filters = {}
clink.prompt.register_filter(reset_prompt_filter, 1)
clink.prompt.register_filter(admin_prompt_filter, 10)
clink.prompt.register_filter(user_prompt_filter, 10)
clink.prompt.register_filter(cwd_prompt_filter, 10)
clink.prompt.register_filter(git_prompt_filter, 10)
clink.prompt.register_filter(env_prompt_filter, 10)
clink.prompt.register_filter(npm_prompt_filter, 10)
clink.prompt.register_filter(agnoster_filter, 99)

-- Load required completion scripts (Adapted from 'clink.lua')
local COMPLETION_SCRIPTS_TO_LOAD = createTable("git_prompt.lua")

local completions_dir = clink.get_env('CMDER_ROOT')..'/vendor/clink-completions/'
for _,lua_module in ipairs(clink.find_files(completions_dir..'*.lua')) do
    if contains(COMPLETION_SCRIPTS_TO_LOAD, lua_module) then
        local filename = completions_dir..lua_module
        -- use dofile instead of require because require caches loaded modules
        -- so config reloading using Alt-Q won't reload updated modules.
        dofile(filename)
    end
end