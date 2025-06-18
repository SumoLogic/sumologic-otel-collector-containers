def result:
    {
        "name": "\(.name)",
        "last_updated": "\(.last_updated)"
    };

def results:
    if has("results") then
        .results | map(result)
    else
        []
    end;

results[]
