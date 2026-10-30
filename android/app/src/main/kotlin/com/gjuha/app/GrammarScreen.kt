package com.gjuha.app

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.gjuha.core.SeedGrammar

/**
 * The grammar guides.
 *
 * Each one opens in place rather than pushing a screen, because a learner
 * reading about definiteness usually wants to glance at the table and go back
 * to the lesson, not to navigate.
 */
@Composable
fun GrammarScreen(content: ContentRepository) {
    val guides = remember { content.grammar }
    var openId by remember { mutableStateOf<String?>(null) }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        items(guides, key = { it.id }) { guide ->
            GuideCard(
                guide = guide,
                isOpen = guide.id == openId,
                onToggle = { openId = if (openId == guide.id) null else guide.id },
            )
        }
    }
}

@Composable
private fun GuideCard(guide: SeedGrammar, isOpen: Boolean, onToggle: () -> Unit) {
    Card(onClick = onToggle, modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.fillMaxWidth().padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(guide.title, fontWeight = FontWeight.Bold, fontSize = 17.sp)
                    if (guide.subtitle.isNotBlank()) {
                        Text(
                            guide.subtitle,
                            fontSize = 13.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                Text(if (isOpen) "−" else "+", fontSize = 20.sp, color = accentStrong())
            }

            AnimatedVisibility(isOpen) {
                Column {
                    Spacer(Modifier.height(12.dp))
                    Text(guide.explanation, fontSize = 15.sp)

                    if (guide.conjugationTable.isNotEmpty()) {
                        Spacer(Modifier.height(16.dp))
                        ConjugationTable(guide.conjugationTable)
                    }

                    if (guide.examples.isNotEmpty()) {
                        Spacer(Modifier.height(16.dp))
                        Text("Examples", fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                        Spacer(Modifier.height(6.dp))
                        for (example in guide.examples) {
                            // The seed writes an example as "Albanian - English".
                            // Split so the Albanian reads as the language being
                            // taught and the gloss stays secondary.
                            val parts = example.split(" - ", limit = 2)
                            Text(parts.first(), fontSize = 14.sp)
                            if (parts.size == 2) {
                                Text(
                                    parts[1],
                                    fontSize = 13.sp,
                                    fontStyle = FontStyle.Italic,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                            Spacer(Modifier.height(8.dp))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ConjugationTable(rows: List<List<String>>) {
    Column(Modifier.fillMaxWidth()) {
        rows.forEachIndexed { index, row ->
            val isHeader = index == 0
            Row(
                Modifier
                    .fillMaxWidth()
                    .background(
                        if (isHeader) MaterialTheme.colorScheme.surfaceVariant
                        else MaterialTheme.colorScheme.surface
                    )
                    .padding(vertical = 8.dp, horizontal = 8.dp),
            ) {
                for (cell in row) {
                    Text(
                        cell,
                        modifier = Modifier.weight(1f),
                        fontSize = 13.sp,
                        fontWeight = if (isHeader) FontWeight.SemiBold else FontWeight.Normal,
                    )
                }
            }
            HorizontalDivider()
        }
    }
}
