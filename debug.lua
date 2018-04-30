if clink.get_env('CLINK_PROMPT_DEBUG') then
    function clink.filter_prompt(prompt)
        local calls, total, this = {}, {}, {}
        
        clink.prompt.value = prompt
        
        local function profile_hook(event)
            local i = debug.getinfo(2, "Sln")
            if i.what ~= 'Lua' then return end
            local func = (i.name or "")..":"..(i.source..' : '..i.linedefined)
            if event == 'call' then
                this[func] = os.clock()
            else
                if this[func] then
                    local time = os.clock() - this[func]
                    total[func] = (total[func] or 0) + time
                    calls[func] = (calls[func] or 0) + 1
                end
            end
        end

        local function unset_profile_hook()
            for f,time in pairs(total) do
                print(("Function %s took %.3f seconds after %d calls"):format(f, time, calls[f]))
            end
            debug.sethook()
        end

        debug.sethook(profile_hook, "cr")

        for _, filter in ipairs(clink.prompt.filters) do
            if filter.f() == true then
                unset_profile_hook()
                return clink.prompt.value
            end
        end

        unset_profile_hook()
        return clink.prompt.value
    end
end