#!/bin/bash

# Configuration : On cherche dynamiquement le fichier
DOC_FILE=$(ls | grep "Environ.md" | head -n 1)

if [[ -z "$DOC_FILE" ]] || [[ ! -f "$DOC_FILE" ]]; then
    echo -e "\e[31mErreur : Fichier documentation non trouvé.\e[0m"
    exit 1
fi

echo -e "\e[1mCible : $DOC_FILE\e[0m"

# Extraction des URLs en excluant les formatages Markdown
# On utilise une exclusion stricte des brackets, parenthèses et quotes
urls=$(grep -oE "https?://[^][ \"')<>]+" "$DOC_FILE" | sed 's/[.,;:)]$//' | sort -u)

if [[ -z "$urls" ]]; then
    echo -e "\e[33mAucun lien trouvé.\e[0m"
    exit 0
fi

count_ok=0
count_err=0
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

echo -e "\e[1mAudit de $(echo "$urls" | wc -l) liens...\e[0m"
echo "--------------------------------------------------------"

while read -r url; do
    [[ -z "$url" ]] && continue
    
    # Audit via HEAD d'abord
    code=$(curl -A "$USER_AGENT" -o /dev/null -s -L -m 5 -w "%{http_code}" -I "$url" 2>/dev/null)
    
    # Fallback GET si HEAD échoue ou 405/000
    if [[ "$code" != "200" ]] && [[ "$code" != "403" ]]; then
        code=$(curl -A "$USER_AGENT" -o /dev/null -s -L -m 10 -w "%{http_code}" "$url" 2>/dev/null)
    fi

    if [[ "$code" == "200" ]]; then
        echo -e "[\e[32m200\e[0m] $url"
        ((count_ok++))
    elif [[ "$code" == "403" ]]; then
        echo -e "[\e[33m403\e[0m] $url (Restreint/Bot protect)"
        ((count_ok++))
    else
        echo -e "[\e[31m${code:-(fail)}\e[0m] $url"
        ((count_err++))
    fi
done <<< "$urls"

echo "--------------------------------------------------------"
echo -e "\e[1mBilan : \e[32m$count_ok Valides\e[0m | \e[31m$count_err Erreurs\e[0m"

[[ $count_err -gt 0 ]] && exit 1 || exit 0
