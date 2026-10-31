package com.gjuha.app

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.gjuha.core.SeedWord

/**
 * The vocabulary the learner has actually met.
 *
 * It lists words that have entered the review schedule rather than the whole
 * seed. A dictionary of 354 words the learner has never seen is a different
 * feature, and showing it here would make "words" mean two things at once.
 */
@Composable
fun WordsScreen(content: ContentRepository, progress: ProgressRepository) {
    var query by remember { mutableStateOf("") }

    val seen = remember {
        val ids = progress.seenWordIds()
        content.words.filter { it.id in ids }.sortedBy { it.albanian.lowercase() }
    }
    val shown = remember(query, seen) {
        if (query.isBlank()) seen
        else seen.filter {
            it.albanian.contains(query, ignoreCase = true) ||
                it.english.contains(query, ignoreCase = true)
        }
    }

    Column(Modifier.fillMaxSize()) {
        if (seen.isNotEmpty()) {
            OutlinedTextField(
                value = query,
                onValueChange = { query = it },
                singleLine = true,
                label = { Text(stringResource(R.string.search_words)) },
                modifier = Modifier.fillMaxWidth().padding(16.dp),
            )
        }

        when {
            seen.isEmpty() -> EmptyWords()
            shown.isEmpty() -> Text(
                "No word matches \"$query\".",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 16.dp),
            )
            else -> LazyColumn(
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                item {
                    Text(
                        if (seen.size == 1) "1 word met so far" else "${seen.size} words met so far",
                        fontSize = 13.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                items(shown, key = { it.id }) { WordCard(it) }
            }
        }
    }
}

@Composable
private fun WordCard(word: SeedWord) {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.fillMaxWidth().padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                // The taught language, not its gloss. It was a step smaller
                // than the English beneath it, which put the translation above
                // the language on a screen whose whole purpose is the
                // language. At this size the diacritics are shapes.
                Text(word.albanian, style = GjuhaType.word)
                Spacer(Modifier.width(8.dp))
                Text(
                    word.partOfSpeech,
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.weight(1f))
                Text(
                    word.cefrLevel.uppercase(),
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Text(word.english, color = MaterialTheme.colorScheme.onSurfaceVariant)

            // Shown only when the seed has one. A placeholder sentence would be
            // teaching material nobody wrote.
            val sentence = word.exampleSentence
            if (!sentence.isNullOrBlank()) {
                Spacer(Modifier.height(10.dp))
                Text(sentence, fontStyle = FontStyle.Italic, fontSize = 14.sp)
                word.exampleTranslation?.takeIf { it.isNotBlank() }?.let {
                    Text(
                        it,
                        fontSize = 13.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}

@Composable
private fun EmptyWords() {
    Column(
        Modifier.fillMaxSize().padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text("📖", fontSize = 44.sp)
        Spacer(Modifier.height(12.dp))
        Text("No words yet", fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Spacer(Modifier.height(4.dp))
        Text(
            "Finish a lesson and the words you meet will collect here.",
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}
