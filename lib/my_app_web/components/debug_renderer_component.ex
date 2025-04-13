defmodule MyAppWeb.Components.DebugRendererComponent do
  use MyAppWeb, :live_component
  alias MyAppWeb.Components.DebugChildComponent
  require Logger

  # Helper to simulate getting items
  defp get_items_to_render(_assigns) do
    # Simulate having multiple items, matching the data keys in ParentLive
    [
      %{id: "item_A", label: "Item A (Source)"},
      %{id: "item_B", label: "Item B (Should hide on jump)"},
      %{id: "item_C", label: "Item C (Target)"}
    ]
  end

  # --- Private helper function to determine item visibility ---
  defp show_item?(item, jump_state) do
    # Safely get jump state values
    is_jump_active = Map.get(jump_state, :active, false)
    source_id = Map.get(jump_state, :source_id)
    target_id = Map.get(jump_state, :target_id)
    Logger.debug("[Renderer show_item? HELPER] Processing item: #{inspect(item.id)}, is_jump_active: #{inspect(is_jump_active)}")

    # Calculate show_item using boolean logic
    show_if_not_active = !is_jump_active
    show_if_active_and_match = is_jump_active &&
                                 ((source_id && item.id == source_id) || (target_id && item.id == target_id))
    show_item = show_if_not_active || show_if_active_and_match

    Logger.debug("[Renderer show_item? HELPER] Calculated show_item: #{show_item} for item: #{inspect(item.id)}")
    show_item # Return the boolean result
  end

  @impl true
  def render(assigns) do
    # Log received assigns at the top
    Logger.debug("[Renderer render ENTRY] Received assigns: #{inspect(assigns)}")
    Logger.debug("[Renderer render ENTRY] Received data specifically: #{inspect(Map.get(assigns, :data))}")
    Logger.debug("[Renderer render ENTRY] Received jump_state specifically: #{inspect(Map.get(assigns, :jump_state))}") # Log received jump_state

    Logger.debug("[Renderer render BEFORE H] Assign @jump_state is: #{inspect(assigns[:jump_state])}") # Log before HEEx

    items = get_items_to_render(assigns)

    ~H"""
    <div class="border p-4 mt-4 border-orange-400">
      <h3 class="text-lg font-medium mb-2">Debug Renderer Component (Refactored Logic)</h3>
       <div class="mb-2 p-2 border bg-gray-50">
         <p>Renderer Received State:</p>
         <pre><code>Data: <%= inspect(@data) %></code></pre>
         <pre><code>Jump State: <%= inspect(@jump_state) %></code></pre> <%# Log inside HEEx top level %>
         <% Logger.debug("[Renderer render IN H TOP] @jump_state is: #{inspect(@jump_state)}") %>
       </div>

       <div class="mt-4 space-y-4">
         <%# --- Loop through items --- %>
         <%= for item <- items do %>
           <div class="border-t pt-2"> <%# Div for structure %>
             <p class="text-xs italic">Inside FOR loop for item <%= item.id %>, @jump_state is: <%= inspect(@jump_state) %></p> <%# Log inside FOR but outside Elixir block %>
             <% Logger.debug("[Renderer render IN FOR OUTSIDE BLOCK] For item #{item.id}, @jump_state is: #{inspect(@jump_state)}") %>
             <%# --- Conditionally render based on the result of the helper function --- %>
             <%= if show_item?(item, @jump_state) do %>
               <%
                 # Log the @data right before calling the child inside the conditional block
                 Logger.debug("[Renderer render IF] Rendering item #{inspect(item.id)} INSIDE if. Current @data: #{inspect(@data)}")
               %>
               <div class="p-2 border border-dashed border-gray-400">
                 <p class="text-sm italic">Rendering item: <%= item.label %></p>
                  <.live_component
                    module={MyAppWeb.Components.DebugChildComponent}
                    id={"child-#{item.id}"} # Use item ID for component ID
                    data={@data}
                    # Pass the specific item being rendered, and the jump state
                    # Child component might need item info later
                    item={item}
                    jump_state={@jump_state}
                  />
                  <%# Use item ID for component ID %>
                  <%# Still pass show_extra down for child's internal logic %>
               </div>
               <% Logger.debug("[Renderer render IF] Finished rendering item #{inspect(item.id)} inside if.") %>
             <% else %>
               <div class="p-2 border border-dashed border-red-400 bg-red-50">
                  <p class="text-sm italic">Skipping item: <%= item.label %> (show_item? returned false)</p>
               </div>
               <% Logger.debug("[Renderer render LOOP] Skipped item #{inspect(item.id)} because show_item? returned false.") %>
             <% end %>
           </div>
         <% end %>
       </div>
    </div>
    """
  end
end
