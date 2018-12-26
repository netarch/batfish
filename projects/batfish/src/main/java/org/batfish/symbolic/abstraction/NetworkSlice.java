package org.batfish.symbolic.abstraction;

import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.PrintWriter;
import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Set;
import java.util.function.Supplier;
import java.util.Collections;
import javax.annotation.Nullable;
import org.batfish.common.bdd.BDDPacket;
import org.batfish.datamodel.Configuration;
import org.batfish.datamodel.HeaderSpace;
import org.batfish.datamodel.Prefix;
import org.batfish.symbolic.Graph;
import org.batfish.symbolic.GraphEdge;
import org.batfish.symbolic.bdd.BDDNetwork;
import org.batfish.symbolic.utils.Tuple;
import com.fasterxml.jackson.databind.ObjectMapper;

public class NetworkSlice {

  private HeaderSpace _headerSpace;

  private Abstraction _abstraction;

  /**
   * Indicates whether this slice is for the catch-all destination equivalence class.
   *
   * @see DestinationClasses#addCatchAllCase
   */
  private boolean _isDefaultCase;

  public NetworkSlice(
      HeaderSpace headerSpace, @Nullable Abstraction abstraction, boolean isDefaultCase) {
    this._headerSpace = headerSpace;
    this._abstraction = abstraction;
    this._isDefaultCase = isDefaultCase;
  }

  public static List<Supplier<NetworkSlice>> allSlices(
      BDDPacket packet, DestinationClasses dcs, int fails) {
    BDDNetwork network = BDDNetwork.create(packet, dcs.getGraph());
    ArrayList<Supplier<NetworkSlice>> classes = new ArrayList<>();
    for (Entry<Set<String>, Tuple<HeaderSpace, Tuple<List<Prefix>, Boolean>>> entry :
        dcs.getHeaderspaceMap().entrySet()) {
      Set<String> devices = entry.getKey();
      HeaderSpace headerspace = entry.getValue().getFirst();
      List<Prefix> prefixes = entry.getValue().getSecond().getFirst();
      Boolean isDefaultCase = entry.getValue().getSecond().getSecond();
      Supplier<NetworkSlice> sup =
          () ->
              AbstractionBuilder.createGraph(
                  dcs, network, devices, headerspace, prefixes, fails, isDefaultCase);

      /* Output the topology */
      Graph g = sup.get()._abstraction.getGraph();
      List<String> sorted_devices = new ArrayList<String>(devices);
      Collections.sort(sorted_devices);
      File file = new File("bonsai-topo." + String.join(".", sorted_devices) + ".log");
      try {
        file.createNewFile();
      } catch (IOException e) {
        e.printStackTrace();
      }
      try {
        PrintWriter writer = new PrintWriter(file);
        Map<String, List<GraphEdge>> em = g.getEdgeMap();
        em.forEach(
            (router, graphEdges) -> {
              graphEdges.forEach(
                  edge -> {
                    writer.println(router + " " + edge.getPeer());
                  });
            });
        writer.close();
      } catch (IOException e) {
        e.printStackTrace();
      }

      /* Output the Node Configuration */
      ObjectMapper objectMapper = new ObjectMapper();
      Map<String, Configuration> conf = g.getConfigurations();
      conf.forEach(
          (node, nodeconf) -> {
                  File file2 = new File(node + ".json");
                  try {
                    file.createNewFile();
                  } catch (IOException e) {
                    e.printStackTrace();
                  }
                  try {
                    objectMapper.writeValue(file2, nodeconf);
                  } catch (IOException e) {
                    e.printStackTrace();
                  }
          });
      classes.add(sup);
    }
    //System.exit(0);
    return classes;
  }

  public HeaderSpace getHeaderSpace() {
    return _headerSpace;
  }

  public Abstraction getAbstraction() {
    return _abstraction;
  }

  public Graph getGraph() {
    return _abstraction.getGraph();
  }

  public boolean getIsDefaultCase() {
    return _isDefaultCase;
  }
}
