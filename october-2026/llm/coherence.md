# Does the answer stay coherent at long context?

The same long prompt, answered with up to 600 tokens at temperature 0. `longest 4-gram run` is the longest stretch of repeated four-word sequences in the answer (1 means no repetition; the gemma4 collapse in May scored 319). The answers themselves quote the private prompt and are not published.

| Model | Prompt | Run | Answer chars | Thinking chars | Longest 4-gram run | Stop |
|---|---|---|---|---|---|---|
| qwen3.8:27b | 64K | 0.40.8, think off, 600 tokens | error |  |  |  |
| qwen3.8:27b | 200K | 0.40.8, think off, 600 tokens | error |  |  |  |
| nemotron-3.5-bolt:74b-a9b | 64K | 0.40.8, think off, 600 tokens | error |  |  |  |
| nemotron-3.5-bolt:74b-a9b | 200K | 0.40.8, think off, 600 tokens | error |  |  |  |
| qwen3.6:35b-mlx | 200K | 0.40.8, think off, 600 tokens | 2517 | 0 | 1 |  |
| gemma4:26b-mlx | 64K | 0.40.8, think off, 600 tokens | 2278 | 0 | 1 |  |
| gemma4:26b-mlx | 200K | 0.40.8, think off, 600 tokens | 2266 | 0 | 1 |  |
| qwen3.8:27b-q4_K_M | 64K | 0.40.8, think off, 600 tokens (27 Oct) | 2383 | 0 | 1 |  |
| qwen3.8:27b-q4_K_M | 200K | 0.40.8, think off, 600 tokens (27 Oct) | 2336 | 0 | 1 |  |
| nemotron-3.5-bolt:74b-a9b | 64K | 0.40.10, think off, 600 tokens | 1839 | 0 | 1 |  |
| nemotron-3.5-bolt:74b-a9b | 200K | 0.40.10, think off, 600 tokens | 2092 | 0 | 1 |  |
| flint:40b | 64K | 0.40.8, thinking allowed, 8,000 tokens (27 Oct) | 0 | 37659 | — | length |
| flint:40b | 200K | 0.40.8, thinking allowed, 8,000 tokens (27 Oct) | 3185 | 21862 | 1 | stop |

## flint:40b's empty answers

flint reasons before it answers. With the 600-token cap at 64K it never reached the answer, with thinking on or off (with `think: false` ollama still generates the tokens and returns neither text). With 8,000 tokens it answered at 200K after 21,862 characters of thinking, and at 64K was still thinking when the cap ran out.

| Prompt | think | Tokens | Answer chars | Thinking chars | Stop |
|---|---|---|---|---|---|
| short | off | 361 | 239 | 0 | stop |
| short | default | 208 | 299 | 743 | stop |
| 64K | off | 600 | 0 | 0 | length |
| 64K | default | 600 | 0 | 2909 | length |

